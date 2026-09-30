-- Manners -- noticing that somebody buffed you: your own auras watched for a
-- new buff and whoever cast it, and the combat log where the client allows
-- it. What is noticed becomes a debt on Queue.lua's owed table, and, for a
-- player who switched it on, a /thank.

local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L
local addon = ns.addon

local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Queue.lua's, which load first.
local plain, JoinName, ForgetUnitAuras = ns.plain, ns.JoinName, ns.ForgetUnitAuras
local UnitHasMana, MANA_CLASSES, SameParty = ns.UnitHasMana, ns.MANA_CLASSES, ns.SameParty
local owed, SaveDebts, TellLedger, NoReading = ns.owed, ns.SaveDebts, ns.TellLedger, ns.NoReading

-- The player's own GUID, read on PLAYER_ENTERING_WORLD (below). The combat log
-- compares both ends of every aura against it.
local playerGUID

---------------------------------------------------------------------------
-- thanking them with an emote
--
-- "Thank them with an emote" (off by default): a favour NoteFavour files for
-- the prompt is answered with C_ChatInfo.PerformEmote("THANK", <their token>),
-- so the game says "You thank Anna." to you and everybody near. This is
-- UNTESTED IN GAME: the API documents a target name, not a unit token, and
-- whether it is held back like SendChatMessage is an assumption. Every doubt
-- therefore ends in no emote rather than a guess, and a throw is swallowed.
---------------------------------------------------------------------------

local ThankFavour
do
	-- Once per person in five minutes, and once for anybody in ten seconds: a
	-- raid buffing you on the pull is not twenty emotes. Only an emote that
	-- went counts; a favour skipped for either is never thanked later.
	local PER_PERSON = 300
	local GAP = 10
	local thankedAt = {} -- [filed name] = GetTime() of the thank
	local lastAt

	-- For /manners debug, since nothing else shows an emote that never came:
	-- the last one made and the last one skipped, with why.
	ns.thankLog = {}

	-- One answer from the client, where a missing function, a throw or a
	-- secret is no answer (nil): pcall covers the first two.
	local function Answer(fn, ...)
		local ok, value = pcall(fn, ...)
		if not ok then return nil end
		return plain(value)
	end

	-- Why the client would not want an emote from addon code now, or nil.
	-- Retail 12.x holds chat from addon code back in an encounter; which
	-- instance does it when, nobody here has seen, so every instance is out,
	-- and so is a client that will not say whether this is one. Then the two
	-- checks other addons on this client make before chatting (EnhanceQoL,
	-- Prat): the messaging lockdown and the Chat restriction state.
	local function Held()
		if InCombatLockdown() then return L["in a fight"] end
		local inside = Answer(_G.IsInInstance)
		if inside ~= false then return L["in an instance"] end
		local encounter = _G.C_InstanceEncounter
		if Answer(encounter and encounter.IsEncounterInProgress) == true
			or Answer(_G.IsEncounterInProgress) == true then
			return L["during an encounter"]
		end
		local chat = _G.C_ChatInfo
		if chat and chat.InChatMessagingLockdown
			and Answer(chat.InChatMessagingLockdown) ~= false then
			return L["chat is restricted"]
		end
		local actions, enum = _G.C_RestrictedActions, _G.Enum
		local kind = enum and enum.AddOnRestrictionType and enum.AddOnRestrictionType.Chat
		local idle = enum and enum.AddOnRestrictionState and enum.AddOnRestrictionState.Inactive
		if kind ~= nil and idle ~= nil and actions and actions.GetAddOnRestrictionState
			and Answer(actions.GetAddOnRestrictionState, kind) ~= idle then
			return L["chat is restricted"]
		end
		return nil
	end

	-- The token Sight read them under, while it still holds them: it may be
	-- a nameplate handed to a bystander since. Never a name, which /thank
	-- could match to somebody else.
	local function Holding(seen)
		local unit = seen.unit
		if type(unit) ~= "string" or unit == "" then return nil end
		if Answer(UnitExists, unit) ~= true then return nil end
		if Answer(ns.UnitFullName, unit) ~= seen.name then return nil end
		if seen.guid ~= nil and Answer(UnitGUID, unit) ~= seen.guid then return nil end
		return unit
	end

	-- C_ChatInfo.PerformEmote, which Blizzard's own chat box calls. The global
	-- DoEmote is a deprecation shim, loaded only with the CVar
	-- loadDeprecationFallbacks on and due to go at the next expansion.
	local function EmoteCall()
		local chat = _G.C_ChatInfo
		if chat and type(chat.PerformEmote) == "function" then return chat.PerformEmote end
		return _G.DoEmote
	end

	local function Skip(name, now, why)
		ns.thankLog.skipped = { name = name, at = now, why = why }
	end

	ThankFavour = function(seen)
		local db = addon.db and addon.db.profile
		if not (db and db.prompt.thankEmote) then return end
		local now, name = GetTime(), seen.name

		local why = Held()
		if why then return Skip(name, now, why) end
		local unit = Holding(seen)
		if not unit then return Skip(name, now, L["no unit for them"]) end
		local last = thankedAt[name]
		if last and now - last < PER_PERSON then
			return Skip(name, now, L["thanked them a moment ago"])
		end
		if lastAt and now - lastAt < GAP then
			return Skip(name, now, L["thanked somebody a moment ago"])
		end

		-- pcall covers both an emote call that throws and one that is not there.
		local ok, answer = pcall(EmoteCall(), "THANK", unit)
		if not ok then
			return Skip(name, now, L["the game would not do it"])
		end
		-- The call reached the game, so both limits are armed whatever it
		-- answered: if the answer below is read backwards, a refusal costs one
		-- thank, where not arming would emote at every favour that came.
		lastAt = now
		-- Swept here rather than on a timer: an emote is rarer than a favour.
		for who, at in pairs(thankedAt) do
			if now - at >= PER_PERSON then thankedAt[who] = nil end
		end
		thankedAt[name] = now
		-- Read the way Blizzard's chat box reads it: true means the emote was
		-- restricted and did not go. The API docs name the same value
		-- "success", so the raw answer goes to /manners debug to settle it.
		answer = plain(answer)
		if answer == true then
			return Skip(name, now, L["the game said it was restricted"])
		end
		ns.thankLog.thanked = { name = name, at = now, answer = tostring(answer) }
	end
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
-- Set by OnEnable in Core.lua, so it lives on ns.
ns.combatLogArmed = false

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
	-- Set while a reading of nothing stands doubted: that scan returned before
	-- rewriting lastPresent, so it still holds the buff from before it ran out,
	-- and is no evidence about the reading before this one. See IsNew. The
	-- next believed scan clears it, and the baseline primes only on those, so
	-- ResetAuraBaseline has nothing to clear.
	local sinceEmpty = false

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
		-- And their PvP flag, which goes on the debt: the owed fallback, with
		-- no token to ask, judges them on it (Queue.lua, "flagged for PvP").
		seen.pvp = ns.PvPFlag(source)
		-- Kept only for the emote, which asks again that it still holds them
		-- (ThankFavour): nothing else may trust a token read a scan ago.
		seen.unit = source
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

	-- Whether the prompt is showing this person, which in a fight is where it
	-- stays until the fight ends. Guarded: Prompt.lua may not have loaded.
	local function FrozenOn(name)
		if not (ns.Prompt and ns.Prompt.Showing) then return false end
		local ok, showing = pcall(ns.Prompt.Showing, ns.Prompt)
		return ok and type(showing) == "table" and showing.name == name
	end

	-- Where the "buffed you" line is not said: a fight in a dungeon or a raid,
	-- where chat belongs to the fight, and anywhere inside a raid, where every
	-- buffer sweeps the raid between pulls and each would get a line. Nobody
	-- in a raid instance is a stranger, so the prompt offers them anyway. The
	-- favour is filed all the same. A client that will not say where you are
	-- gets the line.
	local function QuietHere()
		local ok, inside, kind = pcall(_G.IsInInstance)
		if not ok or plain(inside) ~= true then return false end
		kind = plain(kind)
		if kind == "raid" then return true end
		if kind ~= "party" then return false end
		return InCombatLockdown() and true or false
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
		-- Whether a "buffed you" line is said here at all, asked once for both
		-- kinds of favour: a raid's shouts at every pull are no more news than
		-- its Fortitude.
		local speak = db.verbose and not QuietHere()

		-- Nothing we cast is any use to them, so no debt the queue could never fill.
		if not ns.CouldOffer(hasMana, true) then
			-- A favour all the same, and let go in the moment it arrived.
			TellLedger("Received", seen, true)
			if speak then
				-- Translators: the option's name comes in through its own key, so a
				-- translated line quotes the checkbox the player can find.
				addon:Print(L["|cff80ff80%s buffed you|r -- nothing you cast is any use to them (\"%s\" is on)"]:format(seen.name, L["Skip players it does nothing for"]))
			end
			return
		end

		-- The spell rides along for "In character" (Phrases.lua), which thanks
		-- them by it; the newest favour's, like the class. In memory only.
		owed[seen.name] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
			guid = seen.guid, class = seen.class, pvp = seen.pvp,
			spell = type(seen.key) == "number" and seen.key or nil }
		-- Whether only a buff that reaches your own party could return it: asked
		-- as if they were outside it, about classes rather than where they stand,
		-- so the ledger's row stays true after they join or leave.
		TellLedger("Received", seen, nil, ns.CouldOffer(hasMana, false) == nil)
		-- A warrior's shout reaches the party (in a raid, the subgroup) and
		-- nobody else, so a stranger who buffed one is kept but not on the
		-- prompt, and the line says so, naming the subgroup where that is the
		-- limit. The emote below asks the same.
		local reachable = ns.CouldOffer(hasMana, inParty) ~= nil
		if speak then
			-- "On the prompt" only when a prompt can show it: not through a snooze,
			-- an unlocked prompt or Not while mounted.
			local snoozeEnds = reachable and ns.SnoozeLeft() and ns.SnoozeEndsAt()
			if reachable and ns.PvPHoldsBack(seen.pvp) then
				-- First: whatever else holds the prompt back, this would too.
				-- Said as the snooze line says it: a flag lasts five minutes
				-- after the last fight, longer than a favour is kept by
				-- default, so the return is a maybe, not a promise.
				addon:Print(L["|cff80ff80%s buffed you|r -- they are flagged for PvP, and buffing them would flag you, so returning it is offered only if their flag drops before the favour runs out"]
					:format(seen.name))
			elseif snoozeEnds then
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
			elseif reachable and InCombatLockdown() and not FrozenOn(seen.name) then
				-- The prompt is frozen on somebody else, or hidden, until the
				-- fight ends; only a prompt already on them casts at them now.
				addon:Print(L["|cff80ff80%s buffed you|r -- returning the favour is offered once this fight ends"]
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
		-- Only a favour the prompt can return, as the chat line has it: the
		-- useless one returned above, and one only your party could be
		-- reached with is not thanked either. Guarded and last, so nothing
		-- in it can cost the debt.
		if reachable then ns.Guard("thank emote", ThankFavour, seen) end
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
		if not ns.combatLogArmed then return true end
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
	-- unreadable at either end claims nothing and leaves the aura filed. After a
	-- doubted reading of nothing (the last buff ran out, or death took them all)
	-- the previous reading is stale, so the ending decides then too: a buff
	-- recast under the number it had is new, the same one handed back is not.
	local function IsNew(instanceId, key, expires)
		local known = knownAuras[instanceId]
		if known == nil or known ~= key then return true end
		if not sinceEmpty and lastPresent[instanceId] == key then return false end
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
				-- A readable aura with its number withheld is a refusal too
				-- (some fights withhold single fields): skipped unmarked, two
				-- such scans would prune the baseline empty, and every buff
				-- carried through the fight come back as a favour after it.
				if instanceId == nil then refused = true end
				if instanceId then
					-- The spell is half of the aura's identity, not only a filter.
					local spellId = plain(aura.spellId)
					-- A spell withheld keeps the identity the aura was filed
					-- under: filed as `true` in a fight, the real id afterwards
					-- read as a new aura, and the buff as a new favour. One first
					-- seen withheld stays `true`, so it is still announced once
					-- its spell reads (IsNew): it may have landed in the fight.
					local key = spellId or knownAuras[instanceId] or true
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
		elseif read == 0 and held > 0 then
			doubt = "empty"
			sinceEmpty = true
		end

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
		sinceEmpty = false

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
	if unit == "player" then
		ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs)
		-- Read on the next tick rather than here: a fight fires this on you
		-- many times a second (Core.lua, RememberOwnBuffs).
		ns.ownAurasChanged = true
	end

	-- Keyed by GUID, never the unit token: nameplate tokens are recycled.
	ForgetUnitAuras(plain(UnitGUID(unit)))
end

function addon:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
	playerGUID = plain(UnitGUID("player"))
	wipe(ns.nameplateUnits)
	-- A loading screen, where anybody not grouped was left behind: a favour
	-- from before it no longer proves they are in range. Not a login or a
	-- /reload, where the player has not moved, nor arguments that cannot be
	-- read, which are no evidence of either.
	if plain(isInitialLogin) == false and plain(isReloadingUi) == false then
		ns.zonedAt = GetTime()
	end
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

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
	if unit then ns.nameplateUnits[unit] = true end
end

function addon:NAME_PLATE_UNIT_REMOVED(_, unit)
	if unit then ns.nameplateUnits[unit] = nil end
end
