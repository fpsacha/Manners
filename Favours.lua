-- Manners -- noticing that somebody buffed you: your own auras watched for a
-- new buff and whoever cast it, and the combat log where the client allows
-- it. What is noticed becomes a debt on Queue.lua's owed table while People
-- who buff me is on, and, for a player who switched it on, a /thank -- the
-- one part a class with nothing to give back has too.

local ns = select(2, ...)
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

-- True while the walk of your own buffs that a fight's aura events left due is
-- made after the fight has ended (ns.FlushOwnScan, from PLAYER_REGEN_ENABLED).
-- What it finds landed in the fight, so it is kept as quiet and as unthanked
-- as it would have been had the walk been made there.
local walkAfterFight = false

-- The cast watch's counters, for /manners debug and the full check-up (the code is
-- below, after ClaimFavour): `armed` where it listens at all, `seen` casts kept,
-- `named` landings named from a cast, `late` of them after the window, `several`
-- landings with two or more casters, `none` with nobody to name, `heard` every
-- cast by another player the event brought (`noSpell`, `noUnit`, `noGuid`: those
-- with the spell, the caster or the cast id withheld; `fromGuid`: buff spells read
-- out of a plain cast id), `old` landings read too long after they landed.
ns.castWatch = { armed = false, seen = 0, named = 0, late = 0, several = 0, none = 0, heard = 0, noSpell = 0, noUnit = 0, noGuid = 0, fromGuid = 0, old = 0 }

-- The game's own rule for a spell's cast being withheld when another player casts
-- it (C_Secrets.GetSpellCastSecrecy: 0 never, 1 always, 2 contextually), in words
-- for the check-up.
function ns.CastSecrecyWord(id)
	local v = ns.safecall(C_Secrets and C_Secrets.GetSpellCastSecrecy, id)
	if v == 0 then return "never withheld" end
	if v == 1 then return "always withheld" end
	if v == 2 then return "withheld when another player casts it" end
	return "the game does not say"
end

---------------------------------------------------------------------------
-- thanking them with an emote
--
-- "/thank people who buff me" (off by default): every favour the aura scan
-- hands NoteFavour is answered with C_ChatInfo.PerformEmote("THANK", <their
-- token>), so the game says "You thank Anna." to you and everybody near. It
-- answers being buffed, not the debt: whether you could return it, and People
-- who buff me, play no part, so a rogue thanks too. This is UNTESTED IN GAME:
-- the API documents a target name, not a unit token, and whether it is held
-- back like SendChatMessage is an assumption. Every doubt therefore ends in no
-- emote rather than a guess, and a throw is swallowed.
---------------------------------------------------------------------------

local ThankFavour, ThankUnseen
do
	-- Once per person in five minutes, and once for anybody in ten seconds: a
	-- raid buffing you on the pull is not twenty emotes. Only an emote that
	-- went counts; a favour skipped for either is never thanked later.
	local PER_PERSON = 300
	-- A group member's buffs land again at every lapse (a shout's three
	-- minutes): one /thank in half an hour for them.
	local PER_MEMBER = 1800
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

	-- Why the client would not want an emote from addon code now, or nil. Retail
	-- 12.x holds addon chat back in an encounter, and which instance does it when
	-- nobody here has seen, so every instance is out, as is a client that will not
	-- say. Then the two checks addons on this client make before chatting:
	-- the messaging lockdown and the Chat restriction state. Ahead of all
	-- that, hiding: a text emote reaches everybody near, of either faction, so a
	-- stealthed rogue or a night elf in Shadowmeld would give herself away, and
	-- Feign Death drops combat while the fight goes on. Both are asked of the
	-- player alone, so no secret goes in, and neither is pcalled.
	local function Held(seen)
		if InCombatLockdown() then return L["in a fight"] end
		-- A favour from the fight, found by the walk made as it ended.
		if walkAfterFight then return L["in a fight"] end
		if plain(_G.IsStealthed and _G.IsStealthed()) == true then return L["while stealthed"] end
		if plain(_G.UnitIsFeignDeath and _G.UnitIsFeignDeath("player")) == true then
			return L["in a fight"]
		end
		local inside = Answer(_G.IsInInstance)
		-- A battleground or an arena has a switch of its own (Battle.lua, Thank
		-- people there): somebody of your own team is thanked there, and
		-- nobody else. The checks below still hold it where chat is held.
		if inside == true or inside == 1 then
			local battle = ns.Battle.Thanks(seen)
			if battle == true then
				inside = false
			elseif battle then
				return battle
			end
		end
		if inside ~= false then return L["in an instance"] end
		-- Don't thank anybody while I'm in a party or a raid (prompt.thankNotInGroup).
		-- Not in a battleground or an arena: Thank people there (Battle.lua)
		-- decides there, and inside was cleared above only for that.
		local p = addon.db and addon.db.profile and addon.db.profile.prompt
		if p and p.thankNotInGroup == true and not ns.InBattleground()
			and (plain(_G.IsInRaid and _G.IsInRaid()) == true
				or plain(_G.IsInGroup and _G.IsInGroup()) == true) then
			return L["in a party or a raid"]
		end
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

	-- When a buff from somebody nobody could name was last thanked, by its spell
	-- (Thank them even when I can't see who it was, ThankUnseen below): three
	-- buffs from one unseen druid are one thank, and the same buff again within
	-- PER_PERSON none. A whisper by name for a tokenless favour (ThankByName)
	-- writes here too, so the emote for the same landing does not follow it.
	local unseenAt = {}
	-- How long a whisper by name holds back the unseen emote for its buff, and
	-- the emote that whisper: the two sources' readings of one landing, the
	-- aura scan's able to come a little after the log's.
	local SAME_LANDING = 60

	-- Every rule a thank is held to, asked at the moment it would go: why it
	-- may not (the reason Skip writes down), or nil and the token to thank at.
	-- A favour the combat log named and no token holds (seen.byName) is
	-- whispered by name and has no token: the whisper's own rules (Speech.lua,
	-- WhisperName) decide whether the name is safe to send to.
	-- `noGap` leaves the gap between two thanks out: a thank that waits for a
	-- press (Ask me before thanking, ThankPress.lua) is the player's own, and
	-- two presses are two thanks.
	local function Blocked(seen, now, noGap)
		local name = seen.name
		local why = Held(seen)
		if why then return why end
		local unit = Holding(seen)
		if not unit and not seen.byName then return L["no unit for them"] end
		if seen.byName then
			local at = unseenAt[seen.key]
			if at and now - at < SAME_LANDING then return L["thanked for that buff a moment ago"] end
		end
		local last = thankedAt[name]
		if last and now - last < (seen.inGroup and PER_MEMBER or PER_PERSON) then
			return L["thanked them a moment ago"]
		end
		if noGap then return nil, unit end
		if lastAt and now - lastAt < GAP then
			return L["thanked somebody a moment ago"]
		end
		return nil, unit
	end

	-- The emote a thank-you makes: the one picked, or, with others ticked to
	-- pick from, one of them all at random.
	local pool = {}
	function ns.ThankEmoteToken(prompt)
		local first = prompt and ns.THANK_EMOTE_SET[prompt.thankEmoteToken] and prompt.thankEmoteToken or "THANK"
		local more = prompt and prompt.thankEmoteMore
		if type(more) ~= "table" or next(more) == nil then return first end
		for i = #pool, 1, -1 do pool[i] = nil end
		pool[1] = first
		-- In the list's own order, so the draw is the same for the same ticks.
		for _, token in ipairs(ns.THANK_EMOTES) do
			if more[token] == true and token ~= first then pool[#pool + 1] = token end
		end
		return pool[math.random(#pool)]
	end

	-- The thank itself, once Blocked has let it through. Answers why nothing
	-- went (written down by Skip as well), or nil: a press says it (ThankNow).
	local function Send(seen, emote, whisper, unit, now)
		local name = seen.name
		-- The whisper first (Speech.lua, ns.ThankWhisper): a line to them alone,
		-- which needs no key press where /say would.
		local whispered = whisper and ns.ThankWhisper and ns.ThankWhisper(seen, unit) == true
		if whispered then ns.thankLog.whispered = { name = name, at = now } end
		-- By name, for a landing the aura scan reads with nobody in it: that
		-- reading thanks nobody after this (ThankUnseen, unseenAt).
		if whispered and seen.byName then unseenAt[seen.key] = now end
		local ok, answer = false, nil
		if emote then
			-- pcall covers both an emote call that throws and one that is not there.
			-- The emote the player chose, or the thanks it always was.
			local prompt = ns.db and ns.db.profile and ns.db.profile.prompt
			local token = ns.ThankEmoteToken(prompt)
			ok, answer = pcall(EmoteCall(), token, unit)
		end
		if not ok and not whispered then
			Skip(name, now, L["the game would not do it"])
			return L["the game would not do it"]
		end
		-- The call reached the game, so both limits are armed whatever it
		-- answered: if the answer below is read backwards, a refusal costs one
		-- thank, where not arming would emote at every favour that came.
		lastAt = now
		-- Swept here rather than on a timer: an emote is rarer than a favour.
		for who, at in pairs(thankedAt) do
			if now - at >= PER_MEMBER then thankedAt[who] = nil end
		end
		thankedAt[name] = now
		if not ok then return end
		-- Read the way Blizzard's chat box reads it: true means the emote was
		-- restricted and did not go. The API docs name the same value
		-- "success", so the raw answer goes to /manners debug to settle it.
		answer = plain(answer)
		if answer == true then
			Skip(name, now, L["the game said it was restricted"])
			-- The whisper went: something of the thanks reached them.
			if whispered then return nil end
			return L["the game said it was restricted"]
		end
		ns.thankLog.thanked = { name = name, at = now, answer = tostring(answer) }
	end

	-- Wait a moment before thanking (prompt.thankDelay, off; asked for on
	-- CurseForge: a thank the instant a buff lands reads as an addon's). A pause
	-- of one to three seconds, at random, and then every rule asked again
	-- (Blocked): the giver may have ridden on, a fight begun or the nameplate
	-- gone to somebody else, and then nothing goes and the skip says why. One
	-- thank waits at a time; meanwhile every other favour is passed over as the
	-- gap passes it, so a burst of buffs during the pause is one thank, not a
	-- queue of them, and a second favour from the same person adds nothing.
	local PAUSE_MIN, PAUSE_MAX = 1, 3
	-- The thank waiting out its pause, { name, at }, or nil. One whose timer
	-- never came back (a guard only: C_Timer always calls) holds nothing once it
	-- is well past the longest pause.
	local waiting

	-- The end of the pause: the switches read again, since either may have been
	-- turned off meanwhile, then every rule, then the thank.
	local function Paused(seen, emote, whisper)
		local db = ns.db and ns.db.profile
		if not (db and db.enabled) then return end
		emote = emote and db.prompt.thankEmote == true
		whisper = whisper and db.prompt.thankWhisper == true
		-- A whisper by name goes only while Thank them even when I can't see
		-- who it was is on (ThankByName).
		if seen.byName and db.prompt.thankUnseen ~= true then return end
		if not (emote or whisper) then return end
		local now = GetTime()
		local why, unit = Blocked(seen, now)
		if why then return Skip(seen.name, now, why) end
		Send(seen, emote, whisper, unit, now)
	end

	-- What a thank that waited out its pause leaves behind it when it never
	-- went (they rode off, a fight began, the whisper by name was refused):
	-- the newest named favour passed over meanwhile, then the newest landing
	-- with nobody behind it (ThankUnseen), each only while nothing has gone
	-- since `sent`, so a burst is one thank, not none, and never two.
	local PausedUnseen
	local function Behind(mine, sent)
		local behind = mine.behind
		if behind and lastAt == sent then
			ns.Guard("thank after a pause", Paused, behind.seen, behind.emote, behind.whisper)
		end
		local unseen = mine.unseen
		if unseen and lastAt == sent then
			ns.Guard("thank after a pause", PausedUnseen, unseen)
		end
	end

	-- Asked only with a switch on (NoteFavour): `emote` for the /thank, `whisper`
	-- for a thank-you whispered to somebody you will not buff back. One set of
	-- rules and limits for both, armed by whichever went.
	ThankFavour = function(seen, emote, whisper)
		local now, name = GetTime(), seen.name
		-- Ask me before thanking (prompt.thankAsk; ThankPress.lua): a thank due
		-- by every rule but the gap waits for a press of the prompt, which reads
		-- them all again. No pause: the press is the moment.
		local ask = ns.db and ns.db.profile and ns.db.profile.prompt
		if ask and ask.thankAsk == true and ns.ThankPark then
			local why = Blocked(seen, now, true)
			if why then return Skip(name, now, why) end
			return ns.ThankPark(seen, emote, whisper, false)
		end
		if waiting and now - waiting.at < PAUSE_MAX + 2 then
			-- Somebody else's, kept (the newest) for when the waiting thank never goes.
			if waiting.name ~= name then waiting.behind = { seen = seen, emote = emote, whisper = whisper } end
			return Skip(name, now, waiting.name == name and L["thanked them a moment ago"]
				or L["thanked somebody a moment ago"])
		end
		waiting = nil
		local why, unit = Blocked(seen, now)
		if why then return Skip(name, now, why) end
		local prompt = ns.db and ns.db.profile and ns.db.profile.prompt
		local timer = _G.C_Timer
		if not (prompt and prompt.thankDelay == true and type(timer) == "table" and type(timer.After) == "function") then
			return Send(seen, emote, whisper, unit, now)
		end
		local mine = { name = name, at = now }
		waiting = mine
		ns.thankLog.waiting = mine
		timer.After(PAUSE_MIN + math.random() * (PAUSE_MAX - PAUSE_MIN), function()
			-- Let go before anything can throw, or a throw would hold every
			-- thank back until the guard above lapses.
			if waiting == mine then waiting = nil end
			if ns.thankLog.waiting == mine then ns.thankLog.waiting = nil end
			local sent = lastAt
			ns.Guard("thank after a pause", Paused, seen, emote, whisper)
			-- Nothing went (they rode off, a fight began): the favour passed over
			-- during the pause is thanked instead, so a burst is one thank, not none.
			Behind(mine, sent)
		end)
	end

	-- Thank them even when I can't see who it was (prompt.thankUnseen, off;
	-- asked for on CurseForge by a player who keeps the game's friendly
	-- nameplates off). A class buff from somebody the game gives no token for
	-- has nobody to owe and nobody to /thank at, and a thank went nowhere. With
	-- this on, the emote is made with no target at all, so the game says "You
	-- thank everyone." or the like to everybody near. Every rule a thank obeys
	-- that needs no person: Held (a fight, the walk made as one ends, hiding, an
	-- instance, a battleground, where nobody unseen is of your team, an
	-- encounter, chat held back), the gap between any two thanks, once a buff
	-- in PER_PERSON (so a druid's three buffs, and the same buff again, are one
	-- thank), the pause before thanking, the switches asked again after it. And
	-- one of its own: never with somebody targeted, since an emote with no
	-- name goes at your target. The scan decides what reaches here (Sight,
	-- ThankNobody): a landing, never a refresh or the baseline, of a class buff
	-- with plainly nobody behind it.
	local function SkipUnseen(key, now, why)
		ns.thankLog.unseenSkipped = { key = key, at = now, why = why }
	end

	local function UnseenLive(db)
		return db and db.enabled and db.prompt.thankUnseen == true and db.prompt.thankEmote == true or false
	end

	-- `noGap` as Blocked's; `noTarget` leaves the target out, for a landing a
	-- press will thank (ThankPress.lua): the press reads it, and says to clear it.
	local function UnseenBlocked(seen, now, noGap, noTarget)
		local why = Held(seen)
		if why then return why end
		if not noTarget and Answer(UnitExists, "target") ~= false then return L["you have somebody targeted"] end
		local last = unseenAt[seen.key]
		if last and now - last < PER_PERSON then return L["thanked for that buff a moment ago"] end
		if noGap then return nil end
		if lastAt and now - lastAt < GAP then return L["thanked somebody a moment ago"] end
		return nil
	end

	local function SendUnseen(seen, now)
		local prompt = ns.db and ns.db.profile and ns.db.profile.prompt
		-- No target: the one difference from Send's emote.
		local ok, answer = pcall(EmoteCall(), ns.ThankEmoteToken(prompt))
		if not ok then
			SkipUnseen(seen.key, now, L["the game would not do it"])
			return L["the game would not do it"]
		end
		-- Armed whatever the answer, as Send arms them.
		lastAt = now
		for key, at in pairs(unseenAt) do
			if now - at >= PER_PERSON then unseenAt[key] = nil end
		end
		unseenAt[seen.key] = now
		answer = plain(answer)
		if answer == true then
			SkipUnseen(seen.key, now, L["the game said it was restricted"])
			return L["the game said it was restricted"]
		end
		ns.thankLog.unseen = { key = seen.key, at = now, answer = tostring(answer) }
		ns.Trail("thank", ("thanked somebody unseen with an emote (spell %s)"):format(tostring(seen.key)))
	end

	PausedUnseen = function(seen)
		local db = ns.db and ns.db.profile
		-- The cast watch found the caster on your ignore list: nobody is thanked.
		seen.nobodyWaiting = nil
		if seen.ignoredCaster or seen.nobodyCancelled then
			seen.thankedNobody = nil
			return
		end
		-- It was queued as a thank to nobody (ThankUnseen); only one that goes keeps
		-- the mark that stops a named caster being thanked as well.
		if not UnseenLive(db) then seen.thankedNobody = nil end
		if not UnseenLive(db) then return end
		local now = GetTime()
		local why = UnseenBlocked(seen, now)
		if why then
			seen.thankedNobody = nil
			return SkipUnseen(seen.key, now, why)
		end
		if SendUnseen(seen, now) ~= nil then seen.thankedNobody = nil end
	end

	ThankUnseen = function(seen)
		local db = ns.db and ns.db.profile
		if not UnseenLive(db) then return end
		local now = GetTime()
		-- Ask me before thanking (ThankPress.lua): parked for a press, as ThankFavour parks one.
		if db.prompt.thankAsk == true and ns.ThankPark then
			local why = UnseenBlocked(seen, now, true, true)
			if why then return SkipUnseen(seen.key, now, why) end
			seen.thankedNobody = true
			return ns.ThankPark(seen, true, false, true)
		end
		-- One thank waits out its pause at a time, a named one or this. This
		-- landing is kept behind it (the newest), thanked if that one never goes.
		if waiting and now - waiting.at < PAUSE_MAX + 2 then
			waiting.unseen = seen
			seen.thankedNobody = true
			seen.nobodyWaiting = true
			return SkipUnseen(seen.key, now, L["thanked somebody a moment ago"])
		end
		waiting = nil
		local why = UnseenBlocked(seen, now)
		if why then return SkipUnseen(seen.key, now, why) end
		local timer = _G.C_Timer
		if not (db.prompt.thankDelay == true and type(timer) == "table" and type(timer.After) == "function") then
			if SendUnseen(seen, now) == nil then seen.thankedNobody = true end
			return
		end
		seen.thankedNobody = true
		seen.nobodyWaiting = true
		-- No name: a named favour arriving meanwhile is kept behind it, as
		-- ThankFavour keeps one behind another's.
		local mine = { at = now }
		waiting = mine
		-- Never before the window the cast watch judges the landing over has closed:
		-- only then is it known whether the caster is on your ignore list.
		local pause = PAUSE_MIN + math.random() * (PAUSE_MAX - PAUSE_MIN)
		if seen.awaitCast and seen.high then pause = math.max(pause, seen.high + 0.2 - now) end
		timer.After(pause, function()
			if waiting == mine then waiting = nil end
			local sent = lastAt
			ns.Guard("thank after a pause", PausedUnseen, seen)
			Behind(mine, sent)
		end)
	end

	-- Ask me before thanking (ThankPress.lua): the thank a press sends, every
	-- rule above read again at the press but the gap (two presses are two
	-- thanks), and the token looked for afresh, since the one the landing was
	-- read under may name somebody else by now. Answers why nothing went, or
	-- nil. The switches are the caller's to read.
	ns.ThankNow = {
		Press = function(seen, emote, whisper, unseen)
			local now = GetTime()
			if unseen then
				local why = UnseenBlocked(seen, now, true)
				if why then
					SkipUnseen(seen.key, now, why)
					return why
				end
				return SendUnseen(seen, now)
			end
			local probe = seen
			if not seen.byName then
				probe = {}
				for field, value in pairs(seen) do probe[field] = value end
				probe.unit = ns.UnitFor(seen.name, seen.unit)
			end
			local why, unit = Blocked(probe, now, true)
			if why then
				Skip(seen.name, now, why)
				return why
			end
			return Send(probe, emote, whisper, unit, now)
		end,
		-- Why no thank could go out now for anybody (a fight, hiding, an
		-- instance, an encounter, chat held back), or nil: a thank is not
		-- offered while a press of it could send nothing.
		Held = function(seen)
			return Held(seen)
		end,
	}
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
	-- The entries the baseline primed while the spell was withheld (filed as
	-- `true`), by instance id: what was worn before the walk could name it, as
	-- against a buff first seen in the fight. The first reading with the spell
	-- plain adopts them; see ScanOwnBuffs.
	local primedBlind = {}
	local auraScanPrimed = false
	-- What the last scan of your own buffs made of itself, for /manners debug:
	-- the gate in ScanOwnBuffs can switch this source off without a word, and a
	-- silent stop is the one failure the addon cannot notice on its own. It
	-- starts doubted, because "0 read, baseline 0" is also what a quiet healthy
	-- session prints. `events` and `walks` count UNIT_AURA on you and the walks
	-- those events asked for.
	ns.auraScan = { read = 0, held = 0, doubt = "never scanned", primed = false, events = 0, walks = 0 }
	-- Reused on every UNIT_AURA rather than rebuilt. Wiped at the top of the scan,
	-- never at the bottom, so a re-entrant call (NoteFavour prints, and another
	-- addon can hook chat) sees a clean table rather than a half-built one.
	local present = {}
	-- ...and when each was due to end, beside it so no record is allocated per slot.
	local presentUntil = {}
	-- What the scan before this one read, and whether there was one. Nothing in
	-- the baseline moves on a single reading; see ScanOwnBuffs.
	local lastPresent = {}
	-- ...and when each was due to end as that scan read it, which moves with a
	-- refresh where knownUntil keeps the filed cast's. Read only by IsNew.
	local lastUntil = {}
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

	-- The cast watch's memory (below, after ClaimFavour): the casts other players made
	-- lately, the sightings waiting for a cast to name them, `floor` (the latest moment
	-- the ring is not known to hold every cast, so nothing before it is vouched for) and
	-- `epoch` (a zone change moves it on, which ends the waiting timers' work).
	local cw = { casts = {}, waiting = {}, floor = 0, epoch = 0 }

	-- A baseline settles on two readings that agree, and the second is asked for
	-- on a timer rather than waited for: on a character standing still the next
	-- UNIT_AURA can be minutes away, and anything landing meanwhile would be filed
	-- as already carried. The count bounds what a client that never settles
	-- costs. Both reset on a zone change, the only thing that unprimes a baseline.
	--
	-- The count is spent by every scan the client refuses as well, and a loading
	-- screen, a fight or a match can refuse the list for longer than four seconds.
	-- With the tries gone nothing asked for the second reading when the client
	-- answered again, and the baseline waited for the next UNIT_AURA, which is the
	-- favour itself: in both readings, filed as carried. So a slower stage follows
	-- the fast one, a second apart for thirty scans: half a minute more, for a walk
	-- of forty slots behind one protected call each, made only while the baseline
	-- is unsettled and given back on a zone change like the rest. The gap a landing
	-- can fall into after the client answers is one interval, so up to a second
	-- there, where it was until the next event. A refusal that outlasts both (a
	-- keystone, a long fight) still ends at the next UNIT_AURA.
	local SETTLE_INTERVAL = 0.2
	local SETTLE_TRIES = 20
	local SETTLE_SLOW_INTERVAL = 1
	local SETTLE_SLOW_TRIES = 30
	local settleTries = 0
	local settlePending = false
	-- A timer cannot be called back, so a zone change leaves the old zone's parked
	-- and settlePending true until it fires, up to a second inside the slow stage:
	-- the new zone's first settle scan came that late. Each timer carries the epoch
	-- it was set under, a zone change moves it on and clears the flag, and a timer
	-- from an older one does nothing, not even clear the flag the new chain owns.
	local settleEpoch = 0

	local function ScheduleSettle()
		if settlePending or settleTries >= SETTLE_TRIES + SETTLE_SLOW_TRIES then return end
		if not (C_Timer and C_Timer.After) then return end
		local interval = settleTries < SETTLE_TRIES and SETTLE_INTERVAL or SETTLE_SLOW_INTERVAL
		settleTries = settleTries + 1
		settlePending = true
		local epoch = settleEpoch
		C_Timer.After(interval, function()
			if epoch ~= settleEpoch then return end
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
		wipe(primedBlind)
		wipe(lastPresent)
		wipe(lastUntil)
		wipe(sighted)
		-- The casts seen and the sightings waiting on them mean nothing after a zone
		-- change either; a timer set before it does nothing (epoch).
		wipe(cw.casts) wipe(cw.waiting) cw.floor = GetTime() cw.epoch = cw.epoch + 1
		haveLastScan = false
		auraScanPrimed = false
		settleTries = 0
		settleEpoch = settleEpoch + 1
		settlePending = false
	end

	-- Whether a unit or a name is in your party or raid at all, as BuildQueue's
	-- walk asks it: Salvation's reach, where a shout's is SameParty.
	local function InGroup(who)
		if not who then return false end
		return (plain(UnitInParty and UnitInParty(who)) or plain(UnitInRaid and UnitInRaid(who))) and true
			or false
	end

	-- A class buff that landed with nobody to name, for the full check-up's
	-- trail and the line said once a session about it.
	-- `unseen` is a caster plainly nobody (Sight), which Thank them even when I
	-- can't see who it was thanks, and the line says so.
	local function Unnamed(key, unseen)
		ns.Trail("favour", ("buffed you (spell %s), the caster unnamed"):format(tostring(key)))
		if ns.UnnamedBuffHint then ns.UnnamedBuffHint(unseen == true) end
	end

	-- What became of the last favour seen, for /manners debug (ns.lastFavour). `fate`
	-- is what OweFavour or the cast watch decided; ns.FavourFate moves an owed one on
	-- when the ledger hears how it ended.
	local function Remember(seen, fate, why)
		ns.lastFavour = { name = seen and seen.name, key = seen and seen.key, at = GetTime(), fate = fate, why = why }
	end

	-- Defined after ClaimFavour, with the rest of the cast watch.
	local NameFromCast, AwaitCaster, HeardIgnored

	-- Reads who `source` is into the sighting `seen`: name, GUID, class and the rest, while
	-- the token still means them. Sight reads the aura's own source with it, and the cast
	-- watch the token a cast came from; both rule yourself out first. Returns true once read;
	-- nothing is set for a non-player or somebody on your ignore list. The cast watch has
	-- already asked all of that (NoteCast) and hands over the GUID and the name it read
	-- (`asked`), so the per-cast path asks the client nothing twice.
	local function ReadCaster(source, seen, asked, guid, full)
		if not asked then
			if plain(UnitIsPlayer(source)) ~= true then return end
			-- Somebody on your /ignore list, the game's own "leave me alone": no
			-- debt, no line and no /thank. Asked directly: the token and the GUID
			-- are plain, and either call answers a plain yes or no.
			guid = plain(UnitGUID(source))
			if ns.Ignored(source, guid) then return end
			full = ns.UnitFullName(source)
		end
		if not full then return end

		seen.name = full
		seen.guid = guid
		seen.class = plain(select(2, UnitClass(source)))
		-- Their level, which goes on the debt: the owed fallback, with no token
		-- to ask, names the rank that lands on them by it (Queue.lua, visit).
		local level = plain(UnitLevel(source))
		seen.level = type(level) == "number" and level >= 1 and level or nil
		-- Asked of the token while it still means them, like the name: in
		-- your own party (a shout's reach) and in your party or raid at all
		-- (Salvation's), as BuildQueue's walk asks it.
		seen.sameParty = SameParty(source)
		seen.inGroup = InGroup(source)
		-- And whether the game calls them a tank, which a buff for one target at
		-- a time is offered to (Core.lua, Castable).
		seen.tank = seen.inGroup and ns.IsTankUnit(source) or false
		seen.hasMana = UnitHasMana(source)
		-- And their PvP flag, which goes on the debt: the owed fallback, with
		-- no token to ask, judges them on it (Queue.lua, "flagged for PvP").
		seen.pvp = ns.PvPFlag(source)
		-- Kept only for the emote, which asks again that it still holds them
		-- (ThankFavour): nothing else may trust a token read a scan ago.
		seen.unit = source
		return true
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
		-- Nobody behind it, as the client says plainly: no source at all, not
		-- one withheld (a secret is "cannot tell", never "nobody"; asked by
		-- type, since comparing a secret throws), and a player's cast all the
		-- same. isFromPlayerOrPlayerPet is true for ANY player's aura, not only
		-- yours (Core.lua's blessings read it so, and Blizzard's TargetFrame
		-- passes it as casterIsAPlayer), so it is what tells a stranger from an
		-- NPC no nameplate names either: false is an NPC's, and nil or a secret
		-- cannot tell, none of them thanked. Your own and your pet's casts name
		-- "player" or "pet" and never reach here. Only such a class buff is
		-- thanked with no name (Thank them even when I can't see who it was:
		-- ThankNobody, when the scan files the landing).
		if type(aura.sourceUnit) == "nil" and ns.ALL_BUFF_IDS[key]
			and plain(aura.isFromPlayerOrPlayerPet) == true then
			seen.unseen = true
		end
		-- The game names nobody (nothing, or a withheld source): the cast it saw at that
		-- moment may name them (NameFromCast). Only where the combat log is not the
		-- source of record, and not for an aura plainly an NPC's.
		if not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed
			and plain(aura.isFromPlayerOrPlayerPet) ~= false then
			NameFromCast(seen, aura)
		end
		-- A class buff with no caster to read: a stranger the game gave no
		-- token for, as with the friendly nameplates off. Nobody can be owed
		-- for it, but the trail keeps it, and the player is told why once
		-- (Hints.lua, which says it only when the nameplates are the reason). Not for a
		-- landing waiting on its window: the cast watch says it from Unmatched, so it is
		-- said only when nobody was named.
		if not source and ns.ALL_BUFF_IDS[key] and not seen.awaitCast then Unnamed(key, seen.unseen) end
		-- For /manners debug: a landing nobody could be named for (one waiting on its
		-- window files its own fate, Unmatched; an NPC's is no favour; and where the
		-- combat log is the source of record nothing is known to be unnamed here).
		if not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed and not seen.awaitCast
			and plain(aura.isFromPlayerOrPlayerPet) ~= false then
			Remember(seen, "unnamed", seen.readLate and "old" or "none")
			ns.lastFavour.readLate = seen.readLate
			ns.lastFavour.platesOff = ns.FriendlyPlatesOff() or nil
		end
		if not source or source == "player" then return end
		if plain(UnitIsUnit(source, "player")) then return end
		ReadCaster(source, seen)
		-- A named buff whose caster Manners could not take (yourself, not a player, on your
		-- ignore list, no name): the trail keeps it, for a report.
		if not seen.name and ns.ALL_BUFF_IDS[key] then
			ns.Trail("favour", ("buffed you (spell %s): the game named %s, but not a player Manners can name or buff (yourself, not a player, on your ignore list, or no name)"):format(tostring(key), source))
		end
	end

	-- What the queue would offer somebody (nil for nothing) knowing only whether
	-- they have mana, whether a shout reaches them, and whether they are in
	-- your party or raid at all (Salvation's reach; nil: as inParty). The rest
	-- is set as the queue sets it for a debt, so the two cannot disagree. A buff
	-- for one target at a time asks whether they tank and which class they are
	-- (Core.lua, Castable): without, every member is turned down, the tank too.
	-- With `name`, also who wears one of yours of those right now, read as the
	-- queue reads it (Queue.lua, OneTargetHolders): while yours is on somebody
	-- else, nobody but them is offered it. Without, as if nobody wore one.
	local FAVOUR_HELD = {}
	function ns.CouldOffer(hasMana, inParty, inGroup, isTank, class, name)
		local db = addon.db and addon.db.profile
		if not db then return nil end
		local candidates = ns.CastableBuffs()
		return ns.PickBuffFor(candidates, {
			hasMana = hasMana,
			inGroup = inGroup or inParty,
			inParty = inParty,
			isTank = isTank,
			class = class,
			name = name,
			oneHeld = name and ns.OneTargetHolders(candidates, FAVOUR_HELD) or nil,
			relevantOnly = db.filters.relevantOnly,
			-- Might held from a mage, a warlock or a priest, as the queue holds
			-- it (on by default since the right-buff audit): a paladin with
			-- nothing else to give owes a priest nothing, rather than a favour
			-- that sits as Still owed with nothing on the prompt.
			casterOnly = db.buff.skipCasters == true and ns.CASTER_CLASSES[class] or nil,
			whenBuffed = "always",
			offerAnyway = true,
			-- A favour: a buff kept for one (Buffs.lua, returnOnly) returns it.
			owed = true,
			rotate = false,
		}, NoReading)
	end

	-- Whether the prompt is showing this person, which in a fight is where it
	-- stays until the fight ends. Guarded: the prompt may not have loaded.
	local function FrozenOn(name)
		if not (ns.Prompt and ns.Prompt.Showing) then return false end
		local ok, showing = pcall(ns.Prompt.Showing, ns.Prompt)
		return ok and type(showing) == "table" and showing.name == name
	end

	-- Where the "buffed you" line is not said: a fight in a dungeon or a raid,
	-- where chat belongs to the fight, and anywhere in a raid group, where every
	-- buffer sweeps the raid between pulls -- a raid instance, a world boss, a
	-- battleground's start and every graveyard rez in it -- and in an arena. The
	-- favour is filed all the same; a client that will not say where you are
	-- gets the line.
	local function QuietHere()
		if type(_G.IsInRaid) == "function" and plain(_G.IsInRaid()) == true then return true end
		local ok, inside, kind = pcall(_G.IsInInstance)
		if not ok or plain(inside) ~= true then return false end
		kind = plain(kind)
		if kind == "raid" or kind == "pvp" or kind == "arena" then return true end
		if kind ~= "party" then return false end
		if walkAfterFight then return true end
		return InCombatLockdown() and true or false
	end

	-- When the "buffed you" line was last said about each group member: a
	-- warrior's three-minute shout lapses between pulls and lands again on the
	-- next, a new favour each time, and the line came with every one. Once in
	-- half an hour per member; nobody outside your group meets this. Capped as
	-- ns.lastGave is.
	local LINE_AGAIN = 1800
	local lineAt, lineCount = {}, 0

	-- Whether this favour is a buff back: somebody you buffed first returning
	-- it (asked for on CurseForge: "If I buff someone, because they are nearby,
	-- then they buff me back a minute later, it will start chiming at me to buff
	-- them"). Either Manners saw a buff of yours land on them as a gift (the
	-- ledger's "Gave", not a favour returned) whose time, less its top-up lead,
	-- has not run out (ns.GaveLately) -- WoW Forever names nobody as the caster
	-- of a buff on another player, so this is how it is told there, and it
	-- holds when no token reaches them or the aura cannot be read -- or they
	-- wear a buff the client names you as the caster of, with more than that
	-- lead left. A buff of yours about to run out is no return: they are owed as
	-- ever, and the top-up repays them. Read only for a favour about to be
	-- filed, so a token is asked by name (ns.UnitFor: the one Sight read, if it
	-- still holds them), never trusted from a scan ago.
	local function BuffedBack(db, seen)
		local now = GetTime()
		local opts = { inGroup = seen.inGroup, now = now, refreshUnder = db.filters.refreshUnder }
		local function leadOf(length) return (ns.LeadFor(opts, length)) end
		if ns.GaveLately(seen.name, now, leadOf) then return true end
		local unit = ns.UnitFor(seen.name, seen.unit)
		if not unit then return false end
		local guid = plain(UnitGUID(unit))
		for _, buff in ipairs(ns.CastableBuffs()) do
			local has, remaining, mine, _, seconds = ns.UnitHasBuff(unit, buff, guid)
			if has == true and mine == true and type(remaining) == "number"
				and remaining > leadOf(seconds or (ns.BuffSeconds(buff))) then
				return true
			end
		end
		return false
	end

	-- Whether this favour's giver already wears everything you could give them,
	-- with more than the top-up lead left, whoever cast it (a priest's report on
	-- CurseForge: "it prompts me to buff them back, even if they already have my
	-- priest Fortitude buff and it's just a waste of mana. A thank you is
	-- enough"). Asked as the queue asks it of somebody owed (Queue.lua, visit:
	-- PickBuffFor with spareCovered, whose third value says so), of the token
	-- that names them now, so the favour is let go as it arrives and the line
	-- never promises a prompt that will not come. Not with "Refresh a buff they
	-- already have, to return a favour" on, nor where nobody's buffs are read
	-- (Always offer), nor on a reading kept from before a fight. No
	-- token, or a reading withheld, is not covered: they are owed as ever, and
	-- the queue lets the favour go when a token does read them covered.
	local function ReadOnUnit(buff, opts)
		return ns.UnitHasBuff(opts.unit, buff, opts.guid)
	end
	local function BlockedFor(buff, opts)
		return ns.IsBlocked(opts.name, buff.key, opts.now)
	end
	local function CoveredAlready(db, seen, hasMana, inParty, inGroup)
		local f = db.filters
		local whenBuffed = f.whenBuffed or "skip"
		if f.repayCovered == true or whenBuffed == "always" then return false end
		local unit = ns.UnitFor(seen.name, seen.unit)
		if not unit then return false end
		local candidates = ns.CastableBuffs()
		local guid = plain(UnitGUID(unit))
		local buff, _, covered = ns.PickBuffFor(candidates, {
			unit = unit, guid = guid, name = seen.name, now = GetTime(),
			hasMana = hasMana,
			inGroup = inGroup,
			inParty = inParty,
			isTank = seen.tank,
			class = seen.class,
			oneHeld = ns.OneTargetHolders(candidates, FAVOUR_HELD),
			relevantOnly = f.relevantOnly,
			casterOnly = db.buff.skipCasters == true and ns.CASTER_CLASSES[seen.class] or nil,
			tanksOnly = db.buff.tanksOnly,
			tanksOutside = db.buff.tanksOutside,
			meOnly = db.buff.meOnly,
			whenBuffed = whenBuffed,
			refreshUnder = f.refreshUnder,
			offerAnyway = true,
			owed = true,
			paidUp = true,
			spareCovered = true,
			blocked = BlockedFor,
		}, ReadOnUnit)
		if buff or covered ~= true then return false end
		for i = 1, #candidates do
			if ns.ReadingSource(guid, candidates[i].key) == "kept" then return false end
		end
		return true
	end

	-- The debt a favour leaves, and the chat line about it, while People who buff
	-- me is on (NoteFavour asks). `seen` comes from Sight and nothing is
	-- re-derived from the aura here: by now the token may mean somebody else.
	local function OweFavour(db, seen)
		-- The default, for the returns just below: a favour with nothing to cast for
		-- anybody. Each later way out says its own (ns.lastFavour, /manners debug).
		Remember(seen, "nothing")
		-- Nothing written here could ever reach a prompt with nothing castable for
		-- anybody (a rogue, a buff not learned, every spell switched off, a pin on
		-- one not learned): asked as the queue asks it.
		if #ns.CastableBuffs() == 0 then return end
		local pinned = ns.PinnedBuff()
		if pinned and not ns.IsBuffKnown(pinned) then return end

		-- Then the same question about this person, from what Sight read off the
		-- token (the combat log, which never had one, has the class and the name).
		local hasMana = seen.hasMana
		if hasMana == nil and seen.class then hasMana = MANA_CLASSES[seen.class] == true end
		local inParty = seen.sameParty
		if inParty == nil then inParty = SameParty(seen.name) end
		local inGroup = seen.inGroup
		if inGroup == nil then
			-- The combat log's record, with no token to have asked: by name, and
			-- kept on it for the line below, which says a group member's once
			-- in half an hour. In a fight the log's line comes before the scan's,
			-- so without it a member's lapsing shout was a line at every pull.
			inGroup = InGroup(seen.name)
			seen.inGroup = inGroup
		end
		-- And whether the game calls them a tank, which Sight asks of the token:
		-- the log's record asks by name, which the role and the raid roster both
		-- answer for a member. Without it a tank's favour to a class whose only
		-- buff is for one target at a time was let go.
		if seen.tank == nil then seen.tank = inGroup and ns.IsTankUnit(seen.name) or false end
		-- Whether a "buffed you" line is said here at all, asked once for both
		-- kinds of favour: a raid's shouts at every pull are no more news than
		-- its Fortitude.
		local speak = db.verbose and not QuietHere()
		if speak and seen.inGroup then
			local now, last = GetTime(), lineAt[seen.name]
			if last and now - last < LINE_AGAIN then
				speak = false
			else
				if not last then
					lineCount = lineCount + 1
					if lineCount > 400 then wipe(lineAt) lineCount = 1 end
				end
				lineAt[seen.name] = now
			end
		end

		-- Nothing we cast is any use to them, so no debt the queue could never fill.
		if not ns.CouldOffer(hasMana, true, nil, seen.tank, seen.class) then
			-- A favour all the same, and let go in the moment it arrived.
			Remember(seen, "useless")
			TellLedger("Received", seen, true)
			if speak then
				-- Translators: the option's name comes in through its own key, so a
				-- translated line quotes the checkbox the player can find.
				addon:Print(L["|cff80ff80%s buffed you|r -- nothing you cast is any use to them (\"%s\" is on)"]:format(seen.name, ns.RelevantOnlyLabel and ns.RelevantOnlyLabel() or ""))
			end
			return
		end

		-- A buff back from somebody you buffed first (BuffedBack): no debt, so
		-- nothing on the prompt and no chime; the ledger says so, and so does
		-- the line. A debt already standing for them stays as it was.
		if not owed[seen.name] and BuffedBack(db, seen) then
			Remember(seen, "buffedFirst")
			TellLedger("Received", seen, true, nil, true)
			if speak then
				addon:Print(L["|cff80ff80%s buffed you back|r -- you buffed them first, so nothing is owed"]:format(seen.name))
			end
			return
		end

		-- Nothing to return either when they already wear everything you could
		-- give them, with time to spare, whoever cast it (CoveredAlready): the
		-- favour is written down and let go in the moment it arrived, with its
		-- own reason, and nothing reaches the prompt. A debt already standing
		-- for them stays as it was: the queue judges it.
		if not owed[seen.name] and CoveredAlready(db, seen, hasMana, inParty, inGroup) then
			Remember(seen, "covered")
			TellLedger("Received", seen)
			TellLedger("LetGo", seen.name, "covered")
			if speak then
				addon:Print(L["|cff80ff80%s buffed you|r -- they already have your buff, so there is nothing to return"]:format(seen.name))
			end
			return
		end

		-- The spell rides along for "In character" (Phrases.lua), which thanks
		-- them by it; the newest favour's, like the class. In memory only.
		owed[seen.name] = { expires = GetTime() + db.timing.reciprocateWindow, at = GetTime(),
			guid = seen.guid, class = seen.class, pvp = seen.pvp, level = seen.level,
			spell = type(seen.key) == "number" and seen.key or nil }
		Remember(seen, "owed")
		-- Whether a line was said about it, in memory only: the queue's own
		-- line, should it find them covered and let the favour go, follows one
		-- that promised the prompt and nothing else (Queue.lua, LetGoCovered).
		if speak then owed[seen.name].said = true end
		-- Whether only a buff that reaches your own party could return it: asked
		-- as if they were outside it, about classes rather than where they stand,
		-- so the ledger's row stays true after they join or leave.
		TellLedger("Received", seen, nil, ns.CouldOffer(hasMana, false, nil, seen.tank, seen.class) == nil)
		-- A warrior's shout reaches the party (in a raid, the subgroup) and
		-- nobody else, so a stranger who buffed one is kept but not on the
		-- prompt, and the line says so, naming the subgroup where that is the
		-- limit. Salvation reaches the whole raid: a raider in another
		-- subgroup is on the prompt as the queue offers them.
		local reachable = ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class) ~= nil
		-- And what the queue offers them now: a buff for one target at a time
		-- that is yours on somebody else goes to nobody but them, so the line does
		-- not promise the prompt. The buff it would be, for the line.
		local heldElsewhere
		if reachable and speak then
			if not ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class, seen.name) then
				heldElsewhere = ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class)
				reachable = false
			end
		end
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
				addon:Print(L["|cff80ff80%s buffed you|r -- the prompt is snoozed %s, so returning it is offered only if the snooze ends before the favour runs out"]
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
			elseif heldElsewhere then
				addon:Print(L["|cff80ff80%s buffed you|r -- your %s is on somebody else, and it goes on one target at a time, so returning it is offered only if it comes free before the favour runs out"]
					:format(seen.name, ns.BuffName(heldElsewhere)))
			else
				addon:Print((reachable
					and L["|cff80ff80%s buffed you|r -- returning the favour is on the prompt"]
					or ns.GroupMeansSubgroup() and L["|cff80ff80%s buffed you|r -- what you cast reaches only your own party -- in a raid, your own subgroup -- so they are offered if they join it"]
					or L["|cff80ff80%s buffed you|r -- what you cast reaches your group only, so they are offered if they join it"]):format(seen.name))
			end
		end
		-- Written through rather than left to the logout hook: favours are rare.
		SaveDebts()
	end

	-- Whether something of yours goes back to them now: a debt the queue can
	-- offer where they stand, asked as OweFavour's line asks it. Not one kept
	-- only for if they join your group (a warrior's shout to a stranger), held
	-- by a buff for one target that is on somebody else, or by a PvP flag.
	local function GoesBack(seen)
		if owed[seen.name] == nil then return false end
		local hasMana = seen.hasMana
		if hasMana == nil and seen.class then hasMana = MANA_CLASSES[seen.class] == true end
		local inParty = seen.sameParty
		if inParty == nil then inParty = SameParty(seen.name) end
		local inGroup = seen.inGroup
		if inGroup == nil then inGroup = InGroup(seen.name) end
		if not ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class, seen.name) then return false end
		return not ns.PvPHoldsBack(seen.pvp)
	end

	-- A shout (Battle Shout, Commanding Shout, Horn of Winter) lands on the
	-- whole party again at every pull: never thanked, named or not.
	local function Shout(key)
		local buff = type(key) == "number" and ns.BUFF_BY_ID[key] or nil
		return buff and buff.selfCast and buff.partyOnly and true or false
	end

	-- Whether a buff with nobody named on it may be a group member's after
	-- all. A member always has a token, but a token the client is a moment late
	-- with reads like none, and an emote at nobody for a buff your own group's
	-- priest gave is the wrong manners. So, in a group, the safe answer: a
	-- class buff of a class somebody in the group is (or whose class does not
	-- read), or one of no class at all (Fear Ward and the like, FAVOUR_ONLY),
	-- is never thanked unseen. Out of a group, or a class nobody in it is,
	-- it is a stranger's.
	local function MaybeMember(key)
		local n = plain(_G.GetNumGroupMembers and _G.GetNumGroupMembers()) or 0
		if n <= 0 then return false end
		local buff = type(key) == "number" and ns.BUFF_BY_ID[key] or nil
		local class = buff and buff.class
		if not class then return true end
		local raid = plain(_G.IsInRaid and _G.IsInRaid()) == true
		local prefix = raid and "raid" or "party"
		for i = 1, raid and n or n - 1 do
			local unit = prefix .. i
			if plain(UnitExists(unit)) and not plain(UnitIsUnit(unit, "player")) then
				local theirs = plain(select(2, UnitClass(unit)))
				if theirs == nil or theirs == class then return true end
			end
		end
		return false
	end

	-- A landing the scan filed with plainly nobody behind it (Sight's
	-- seen.unseen): thanked with no name while Thank them even when I can't
	-- see who it was is on (ThankUnseen, which asks the switches and every
	-- rule). Never a shout, never what may be a group member's.
	local function ThankNobody(seen)
		if Shout(seen.key) or MaybeMember(seen.key) then return end
		-- A cast from somebody on your ignore list is already in the ring: no thank,
		-- not even to nobody (Decide drops one still waiting when it learns it later).
		if seen.awaitCast and HeardIgnored and HeardIgnored(seen) then
			seen.ignoredCaster = true
			return
		end
		-- ThankUnseen marks `seen.thankedNobody` where a thank to nobody went, was
		-- parked or was queued behind a pause, so a caster the cast watch names after
		-- the window is not thanked a second time (NoteFavour, noThank), and is
		-- thanked when none was sent.
		ns.Guard("thank unseen", ThankUnseen, seen)
	end

	-- A favour the combat log named and no token holds: with Thank them even
	-- when I can't see who it was and the whispered thank-you both on, the
	-- whisper goes by name (Speech.lua, ns.ThankWhisper, whose WhisperName asks
	-- the client by the GUID that a bare name is somebody of your own realm),
	-- under the whisper's own rules (GoesBack, ThankFavour's). Anybody a token
	-- does hold is the aura scan's to thank, as ever, so the ordinary thank is
	-- never doubled; and a whisper that went keeps the scan's reading of the
	-- same landing, with nobody in it, from thanking again (unseenAt).
	local function ThankByName(db, seen)
		if not (db.prompt.thankUnseen == true and db.prompt.thankWhisper == true) then return end
		if type(seen.name) ~= "string" or ns.UnitFor(seen.name) then return end
		if Shout(seen.key) or GoesBack(seen) then return end
		seen.byName = true
		ns.Guard("thank emote", ThankFavour, seen, false, true)
	end

	-- One favour, filed against the person who was holding the token when the aura
	-- was read: a debt while People who buff me is on, and a /thank while its own
	-- switch is. Either one alone has the scan read who cast it (ScanOwnBuffs,
	-- watching). `owe` is false for a landing the other source claimed first
	-- (ClaimFavour): the combat log, which has filed the debt and left the
	-- /thank to the aura scan, the one with a token to thank at.
	local function NoteFavour(seen, owe)
		local db = addon.db and addon.db.profile
		if not db then return end
		ns.Trail("favour", ("buffed you (spell %s, %s, %s)"):format(tostring(seen.key),
			seen.fromCast and "named from their cast" or seen.unit and "read off the auras" or "read off the combat log",
			seen.inGroup and "in your group" or "not in your group"), seen.name)

		-- With the addon off nothing is noticed at all; the scan checks too, but
		-- the setting can change between the sighting and here.
		if not db.enabled then return end

		-- Their buff landed on you: it ends what a death let Manners infer (GoneWithDeath).
		local landed = type(seen.key) == "number" and ns.BUFF_BY_ID[seen.key] or nil
		if landed then ns.NoteCastSinceDeath(landed.key) end

		-- With this source off, no debt: it could never reach a prompt.
		if owe and db.sources.owed then OweFavour(db, seen) end
		-- A log line, which has no token to thank at: the aura scan thanks for
		-- the same landing when it reads it, claimed by the log or not. Only
		-- somebody no token holds is whispered by name from here (ThankByName).
		if not seen.unit then ThankByName(db, seen) end
		if not seen.unit then return end
		-- Named late from their cast, after a thank to nobody went (AwaitCaster): the
		-- one landing is thanked once.
		if seen.noThank then return end
		-- The /thank answers being buffed, not the debt, so a favour you cannot
		-- return is thanked, and a rogue or a hunter with nothing to give back
		-- thanks too. Its rules are ThankFavour's. Guarded and last, so nothing
		-- in it can cost the debt.
		-- Never for a shout (Battle Shout, Commanding Shout, Horn of Winter): it
		-- lands on the whole party again at every pull, and a /thank at the
		-- warrior each time is not manners. Still a favour, as before.
		local buff = type(seen.key) == "number" and ns.BUFF_BY_ID[seen.key] or nil
		if buff and buff.selfCast and buff.partyOnly then return end
		-- A whispered thank-you, for somebody you will not buff back: nothing
		-- of yours is owed them (a warrior, a class with nothing for them, or
		-- People who buff me off), or a debt that cannot go back to them now
		-- (GoesBack). A favour you return is thanked by that.
		local whisper = db.prompt.thankWhisper == true and not GoesBack(seen)
		if db.prompt.thankEmote or whisper then
			ns.Guard("thank emote", ThankFavour, seen, db.prompt.thankEmote == true, whisper)
		end
	end

	-- One buff landing, seen by two sources that cannot see each other (a log line
	-- has no instance id), agreed on who cast what. A mark is claimed by the
	-- first source and CONSUMED by the other, so a genuine recast afterwards is
	-- still announced (STATUS.md). A mark nobody consumes (the stranger only the
	-- log sees) suppresses a real recast until it expires, so the window is the
	-- aura scan's longest deferral, both settle stages together, plus a tick.
	local NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES)
		+ (SETTLE_SLOW_INTERVAL * SETTLE_SLOW_TRIES) + 1
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

	---------------------------------------------------------------------------
	-- naming a favour's caster from the casts seen at that moment (issue 26)
	--
	-- Where the combat log is not armed (Forever, retail, a classic client whose log
	-- was refused) a stranger's buff on you can arrive with no caster the addon can
	-- read: sourceUnit nil, or withheld. The cast itself is seen by everybody in
	-- sight: UNIT_SPELLCAST_SUCCEEDED, for the token the client gives for another
	-- player (a nameplate, your target, focus, mouseover, your group). So every class
	-- buff cast by somebody else is kept in a small ring for a few seconds (OnCast,
	-- NoteCast), and a landing that names nobody asks the ring who cast that buff in
	-- the second either side of it (Judge). The rule is the one a person would use:
	-- exactly ONE player in sight cast it then, or nobody is named. A wrong name is
	-- worse than none, so everything that cannot be told is "cannot tell":
	--   * the ring only vouches for a moment it recorded in full (`floor`: anything it
	--     did not record, or dropped, is a moment it cannot vouch for);
	--   * a cast by an NPC, or by somebody whose status cannot be read, or at somebody
	--     else, or a group form of the buff, is no candidate but still counts as a
	--     second person;
	--   * every landing waits for its window to close (Decide), which prefers the cast
	--     aimed at you; one with no target is a self-cast as often as not, so it
	--     names them only while the friendly nameplates are on (else other players may
	--     have cast it out of sight) and when they plainly do not now wear a fresh one
	--     of it themselves (SelfCast);
	--   * a cast whose target cannot be read, and your own casts of a class buff, are
	--     no candidate either, but count as somebody else.
	---------------------------------------------------------------------------
	-- Read at load, as ns.plain reads it: absent on a client that never had secrets.
	local issecretvalue = _G.issecretvalue

	do
		local CAST_WINDOW = 1.0     -- either side of the landing
		local CAST_SAME = 0.5       -- two sightings of one cast, by one person
		local CAST_KEEP = 6         -- how long a cast stays in the ring
		local CAST_RING_MAX = 32
		local AWAIT_MAX = 8         -- landings waiting for their window to close (a
		                            -- buff round lands several in one second)
		local LANDED_OLDEST = 4     -- the oldest landing a cast can explain; with the
		                            -- window and a tick it stays inside CAST_KEEP
		local COPIED = { "name", "guid", "class", "level", "sameParty", "inGroup",
			"tank", "hasMana", "pvp", "unit" }

		-- Why a landing was left with nobody named, for the trail.
		local UNMATCHED_WHY = {
			none = "no player in sight was seen casting it on you",
			unreadable = "a cast was seen but Manners could not tell who made it, or could not vouch for that moment",
			npc = "the cast it saw was not a player's",
			group = "the cast it saw was the group form of the buff, which lands on the caster's own group",
			["else"] = "the cast it saw was aimed at somebody else",
			theirOwn = "the cast it saw looks like their own, on themselves",
			unseen = "the nameplates were off or the caster could not be checked, and other players may have cast it out of sight",
			own = "the cast it saw was your own",
		}

		local function InList(list, id)
			if type(list) ~= "table" then return false end
			for i = 1, #list do
				if list[i] == id then return true end
			end
			return false
		end

		local function SameBuff(a, b)
			return a == b or (ns.BUFF_BY_ID[a] ~= nil and ns.BUFF_BY_ID[a] == ns.BUFF_BY_ID[b])
		end

		-- Whether two ring entries are one person. A caster who cannot be identified
		-- always counts as somebody else.
		local function SamePerson(a, b)
			if a.guid ~= nil and b.guid ~= nil then return a.guid == b.guid end
			if a.guid == nil and b.guid == nil then
				local x, y = a.seen and a.seen.name, b.seen and b.seen.name
				return x ~= nil and x == y
			end
			return false
		end

		-- Whether a cast of this buff from somebody on your ignore list is in the ring
		-- for this landing's window.
		HeardIgnored = function(seen)
			local casts = cw.casts
			for i = 1, #casts do
				local e = casts[i]
				if e.ignored and e.at >= seen.low and SameBuff(e.spell, seen.key) then return true end
			end
			return false
		end

		local function CopyCaster(src, dst)
			for i = 1, #COPIED do dst[COPIED[i]] = src[COPIED[i]] end
		end

		-- When the aura landed, on GetTime's clock, and how late the reading may be:
		-- from the aura's own timer where it gives both end and length; else the time
		-- of the reading, which a walk can make up to one tick after the event.
		-- nil and how long ago: it landed too long ago to be explained by a cast.
		local function LandedAt(aura, now)
			local ends, length = plain(aura.expirationTime), plain(aura.duration)
			if type(ends) == "number" and type(length) == "number" and ends > 0 and length > 0 then
				local t = ends - length
				if t > now + 0.5 then return now, 0 end
				if t < now - LANDED_OLDEST then return nil, now - t end
				return t, 0
			end
			local db = addon.db and addon.db.profile
			return now, db and db.timing and db.timing.scanInterval or 0.4
		end

		-- Who cast `key` between `low` and `high`: the one-person rule. Returns the
		-- ring entry, or "ignored" and the entry, or nil and why.
		local function Judge(key, low, high)
			if low <= cw.floor then return nil, "unreadable" end
			local casts = cw.casts
			local first, best, blocked
			for i = 1, #casts do
				local e = casts[i]
				if e.at >= low and e.at <= high and SameBuff(e.spell, key) then
					if not first then
						first = e
					elseif not SamePerson(first, e) then
						return nil, "several"
					end
					-- Blocked, ignored and unreadable casts count as people above; the
					-- one that names the landing is the aimed-at-you cast if there is
					-- one, else their first cast that has not named a landing yet.
					if e.block then blocked = e.block end
					if not e.used then
						if e.aim == "you" then
							if not (best and best.aim == "you") then best = e end
						elseif not best then
							best = e
						end
					end
				end
			end
			if not first then return nil, "none" end
			if not best then return nil, "none" end
			if best.aim ~= "you" and blocked then return nil, blocked end
			if best.ignored then return "ignored", best end
			if not (best.seen and best.seen.name) then return nil, "unreadable" end
			return best
		end

		-- Whether a cast with no target was their own: true when somebody who now wears
		-- a fresh one of the buff, cast at the moment, cast it on themselves; false when
		-- they plainly do not; nil when it cannot be told. The global cooldown keeps
		-- two casts by one person at least 1.5 s apart, so a priest who buffed herself
		-- and then you is still named. "Not wearing it" counts only when their auras
		-- are shown readable in the same call: a list the client hides says nothing.
		local function SelfCast(e)
			if e.guid == nil or plain(UnitGUID(e.unit)) ~= e.guid then return nil end
			if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then return nil end
			-- Read straight off the caster, whatever class they are: the class buff
			-- tables hold only your own class's buffs, and most favours are another
			-- class's. Runs from Decide, which runs from a timer (or at once where the
			-- client has none), so a protected call is allowed.
			local buff = ns.BUFF_BY_ID[e.spell]
			local ids = buff and buff.auraIds or { e.spell }
			local cannotTell = false
			for i = 1, #ids do
				local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, e.unit, ids[i])
				if not ok or (issecretvalue and issecretvalue(aura)) then
					cannotTell = true
				elseif type(aura) == "table" then
					local ends, length = plain(aura.expirationTime), plain(aura.duration)
					if type(ends) ~= "number" or type(length) ~= "number" or ends <= 0 or length <= 0 then
						cannotTell = true
					elseif math.abs((ends - length) - e.at) <= 0.75 then
						return true
					end
				end
			end
			if cannotTell then return nil end
			-- None of the ids found: not wearing it, but only if the list is readable.
			local get = C_UnitAuras.GetAuraDataByIndex
			if not get then return nil end
			local ok, first = pcall(get, e.unit, 1, "HELPFUL")
			if not ok or type(first) ~= "table" or (issecretvalue and issecretvalue(first)) then return nil end
			return false
		end

		local function Forget(seen)
			local waiting = cw.waiting
			for i = 1, #waiting do
				if waiting[i] == seen then table.remove(waiting, i) break end
			end
		end

		-- A landing nobody could be named for, once its window has closed (or given up
		-- on): counted, written down, and said once if the nameplates are on.
		local function Unmatched(seen, why)
			local stat = ns.castWatch
			if why == "several" then stat.several = stat.several + 1 else stat.none = stat.none + 1 end
			if why == "several" then
				ns.Trail("favour", ("buffed you (spell %s): two or more players in sight cast it then, so nobody is named"):format(tostring(seen.key)))
			else
				ns.Trail("favour", ("buffed you (spell %s): the game did not say who cast it, and %s"):format(
					tostring(seen.key), UNMATCHED_WHY[why] or "no cast could name them"))
			end
			Remember(seen, "unnamed", why)
			ns.lastFavour.platesOff = ns.FriendlyPlatesOff() or nil
			-- Nobody was named, so now the trail's line and the nameplates hint (Sight
			-- leaves both to here for a landing that waited on its window).
			Unnamed(seen.key, seen.unseen)
			if ns.UnmatchedBuffHint then ns.UnmatchedBuffHint(why) end
		end

		-- The window has closed: one decision, seeing every cast in it.
		local function Decide(seen)
			if seen.decided then return end
			seen.decided = true
			Forget(seen)
			local hit, why = Judge(seen.key, seen.low, seen.high)
			-- A cast not aimed at you may name its caster only while the friendly
			-- nameplates are plainly on (off, a stranger out of sight may have cast
			-- it, and the one seen is a bystander) and it is plainly no self-cast.
			-- Aimed at you is no proof either: with you targeted, the self-cast key or a
			-- mouseover macro sends it elsewhere. A caster who plainly wears a fresh one
			-- cast at that moment cast it on themselves; "cannot tell" still names them.
			if type(hit) == "table" and hit.aim == "you" and SelfCast(hit) == true then
				hit, why = nil, "theirOwn"
			end
			if type(hit) == "table" and hit.aim ~= "you" then
				if ns.FriendlyPlatesOff() then
					hit, why = nil, "unseen"
				else
					local mine = SelfCast(hit)
					if mine == true then
						hit, why = nil, "theirOwn"
					elseif mine == nil then
						hit, why = nil, "unseen"
					end
				end
			end
			if hit == "ignored" then
				-- A thank to nobody may already have gone; it named nobody. One still
				-- waiting out its pause or for a press is let go (PausedUnseen, ThankPress).
				seen.ignoredCaster = true
				Remember({ name = why.seen and why.seen.name, key = seen.key }, "ignored")
				return
			end
			if type(hit) == "table" then
				CopyCaster(hit.seen, seen)
				hit.used = true
				-- The same cast heard under another token (one person, one buff, the same
				-- moment) is spent with it, even with every id withheld: one cast names one
				-- landing.
				local casts = cw.casts
				for i = 1, #casts do
					local e = casts[i]
					if not e.used and SamePerson(hit, e) and SameBuff(e.spell, hit.spell)
						and math.abs(e.at - hit.at) <= CAST_SAME then
						e.used = true
					end
				end
				seen.fromCast = true
				seen.filed = true
				-- A thank to nobody still waiting is let go for the name (the pause ends,
				-- PausedUnseen drops it, and the named thank behind it goes).
				if seen.nobodyWaiting then
					seen.nobodyCancelled = true
					seen.thankedNobody = nil
				end
				seen.noThank = seen.thankedNobody
				local stat = ns.castWatch
				stat.named = stat.named + 1
				stat.late = stat.late + 1
				ns.Trail("favour", ("named from their cast, %.1fs after the buff landed (spell %s)"):format(
					GetTime() - seen.landedAt, tostring(seen.key)), seen.name)
				-- Replayed as it was the moment it landed.
				local was = walkAfterFight
				walkAfterFight = seen.afterFight or was
				ns.Guard("favour", NoteFavour, seen, ClaimFavour(seen.name, seen.key))
				walkAfterFight = was
				return
			end
			Unmatched(seen, why)
		end

		-- A landing that cannot wait for its window to close: nobody is named.
		local function GiveUp(seen)
			if seen.decided then return end
			seen.decided = true
			Forget(seen)
			Unmatched(seen, "unreadable")
		end

		-- The landing has no caster the aura names: fix the window its casts fall in.
		-- Every such landing is judged once the window has closed (AwaitCaster, from
		-- the scan's fresh loop), over every cast in it, which prefers the one aimed at
		-- you; none is named on what the ring holds at the moment it lands.
		NameFromCast = function(seen, aura)
			local now = GetTime()
			local landed, lag = LandedAt(aura, now)
			if landed == nil then
				seen.readLate = lag
				ns.castWatch.old = ns.castWatch.old + 1
				ns.Trail("favour", ("buffed you (spell %s): Manners first read it %d s after it landed, by its own timer, too long ago to match a cast"):format(tostring(seen.key), math.floor(lag + 0.5)))
				return nil
			end
			seen.low, seen.high = landed - CAST_WINDOW - lag, landed + CAST_WINDOW
			seen.landedAt = landed
			seen.awaitCast = true
			return true
		end

		-- Park a landing until the last cast that could name it has had its moment.
		AwaitCaster = function(seen)
			seen.parked = true
			seen.afterFight = walkAfterFight or nil
			local waiting = cw.waiting
			if #waiting >= AWAIT_MAX then
				-- The oldest is judged if its window has closed; judged early, a second
				-- player's cast still to come in it could not make it "several", so one
				-- still open is given up on, naming nobody.
				local old = table.remove(waiting, 1)
				if GetTime() > old.high then Decide(old) else GiveUp(old) end
			end
			waiting[#waiting + 1] = seen
			local wait = math.max(seen.high + 0.1 - GetTime(), 0)
			if not (C_Timer and C_Timer.After) then
				-- No timer to wait on: decided only once the window has closed.
				if wait > 0 then GiveUp(seen) else Decide(seen) end
				return
			end
			-- A window already closed is decided on the next frame, not from inside the
			-- scan that is filing the landing.
			local epoch = cw.epoch
			C_Timer.After(wait, function()
				if epoch == cw.epoch then ns.Guard("cast watch", Decide, seen) end
			end)
		end

		-- With the ignore list empty (the client says plainly: none), nobody needs asking
		-- about; a client that cannot say is asked as ever.
		local function NobodyIgnored()
			local friends = _G.C_FriendList
			return type(friends) == "table" and type(friends.GetNumIgnores) == "function"
				and plain(friends.GetNumIgnores()) == 0
		end

		-- Your own cast of a class buff, as a blocking entry; one cast heard under two
		-- tokens is one entry.
		local function OwnCast(now, unit, cast, id)
			local casts = cw.casts
			for i = 1, #casts do
				local e = casts[i]
				if e.block == "own" and SameBuff(e.spell, id)
					and ((cast ~= nil and e.cast == cast) or now - e.at < CAST_SAME) then return end
			end
			casts[#casts + 1] = { at = now, spell = id, cast = cast, guid = playerGUID, unit = unit, block = "own" }
			if #casts > CAST_RING_MAX then
				cw.floor = math.max(cw.floor, table.remove(casts, 1).at)
			end
		end

		-- One cast, past the switches: who, at whom, and what they are. Your own casts of
		-- a class buff go in as a blocking entry (`own`): a recast of your own buff on
		-- yourself, the game naming nobody, must never name a stranger who cast near it.
		local function NoteCast(unit, cast, id)
			local now = GetTime()
			local casts = cw.casts
			while casts[1] and casts[1].at < now - CAST_KEEP do
				cw.floor = math.max(cw.floor, casts[1].at)
				table.remove(casts, 1)
			end
			if type(cast) ~= "string" then cast = nil end
			if unit == "player" or unit == "pet" then return OwnCast(now, unit, cast, id) end
			if ns.IsOwnAura(id) or ns.NOT_FAVOUR_IDS[id] then return end
			local guid = plain(UnitGUID(unit))
			if type(guid) ~= "string" then guid = nil end
			-- Your own cast arriving under a token that means you (your target, say).
			if (guid ~= nil and guid == playerGUID) or plain(UnitIsUnit(unit, "player")) == true
				or plain(UnitIsUnit(unit, "pet")) == true then
				return OwnCast(now, unit, cast, id)
			end
			-- The same cast reaches the frame once per token that means the caster: one
			-- cast of that GUID by that caster (a shared or recycled cast GUID of another
			-- player is another cast).
			for i = 1, #casts do
				local e = casts[i]
				if guid ~= nil and e.guid == guid then
					if cast ~= nil and e.cast == cast then return end
					if SameBuff(e.spell, id) and now - e.at < CAST_SAME then return end
				end
			end
			local e = { at = now, spell = id, cast = cast, guid = guid, unit = unit }
			-- A group form or a shout lands on the caster's own group, whose members the
			-- aura names: it may stop a naming, never make one.
			local buff = ns.BUFF_BY_ID[id]
			if buff and (buff.selfCast or InList(buff.group, id)) then e.block = "group" end
			-- An NPC, or somebody whose kind cannot be read, blocks too.
			local isPlayer = plain(UnitIsPlayer(unit)) == true
			if not isPlayer then e.block = e.block or "npc" end
			if not e.block then
				-- Whom they have targeted. A withheld answer is not "nobody": only a plain
				-- no target is unknown (a self-cast as often as not); anything unreadable
				-- blocks.
				local t = unit .. "target"
				local ex = plain(UnitExists(t))
				if ex == nil then
					e.block = "unreadable"
				elseif ex == true then
					local me = plain(UnitIsUnit(t, "player"))
					if me == nil then
						e.block = "unreadable"
					else
						e.aim = me == true and "you" or "else"
						if e.aim == "else" then e.block = "else" end
					end
				else
					e.aim = "unknown"
				end
			end
			if not e.block then
				e.ignored = not NobodyIgnored() and ns.Ignored(unit, guid) or nil
				if not e.ignored then
					local full = ns.UnitFullName(unit)
					if full then
						local rec = {}
						if ReadCaster(unit, rec, true, guid, full) then e.seen = rec end
					end
				end
			end
			-- A caster whose GUID is withheld cannot be told apart by it: one cast
			-- (one cast GUID) heard under two tokens is one entry when both tokens read
			-- the same name, else both stay and count as two people (naming nobody).
			if guid == nil and cast ~= nil and e.seen then
				for i = 1, #casts do
					local x = casts[i]
					if x.guid == nil and x.cast == cast and x.seen and x.seen.name == e.seen.name
						and SameBuff(x.spell, id) then return end
				end
			end
			casts[#casts + 1] = e
			if #casts > CAST_RING_MAX then
				local removed = table.remove(casts, 1)
				cw.floor = math.max(cw.floor, removed.at)
			end
			ns.castWatch.seen = ns.castWatch.seen + 1
		end

		-- The spell a cast id carries, "Cast-<type>-<server>-<instance>-<zone>-<spell>-<cast>"; nil for any other shape. Only ever handed a plain string.
		local function SpellOfCast(guid)
			local id = guid:match("^Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
			return id and tonumber(id) or nil
		end

		-- UNIT_SPELLCAST_SUCCEEDED for every unit, so it drops what is no class buff
		-- with one table lookup, before any client call and with no protected call, and
		-- drops the rest too when nothing could use a named caster.
		local function OnCast(_, _, unit, castGUID, spellID)
			local id = plain(spellID)
			local who = plain(unit)
			if who ~= "player" and who ~= "pet" then
				local stat = ns.castWatch
				stat.heard = stat.heard + 1
				if who == nil then stat.noUnit = stat.noUnit + 1 end
				local secretGuid = issecretvalue ~= nil and issecretvalue(castGUID) == true
				if secretGuid then stat.noGuid = stat.noGuid + 1 end
				if id == nil then
					stat.noSpell = stat.noSpell + 1
					if not secretGuid and type(castGUID) == "string" then
						id = SpellOfCast(castGUID)
						if id ~= nil and ns.ALL_BUFF_IDS[id] then stat.fromGuid = stat.fromGuid + 1 end
					end
				end
				-- A cast nobody can read (spell or caster withheld) may be a second player's buff: the moment is not vouched for.
				if id == nil or (who == nil and ns.ALL_BUFF_IDS[id]) then cw.floor = GetTime() return end
			end
			if id == nil or not ns.ALL_BUFF_IDS[id] then return end
			unit = who
			if type(unit) ~= "string" then return end
			local db = addon.db and addon.db.profile
			if not (db and db.enabled) then cw.floor = GetTime() return end
			-- Not primed, or nothing a named caster could be used for: the ring misses
			-- this cast, so the moment is not vouched for.
			if not auraScanPrimed
				or not (db.sources.owed or ((db.prompt.thankEmote or db.prompt.thankWhisper)
					and not InCombatLockdown())) then
				cw.floor = GetTime()
				return
			end
			ns.Guard("cast watch", NoteCast, unit, plain(castGUID), id)
		end

		function ns.ArmCastWatch()
			if ns.castWatch.armed then return end
			if not cw.frame then
				cw.frame = CreateFrame("Frame")
				cw.frame:SetScript("OnEvent", OnCast)
			end
			cw.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
			ns.castWatch.frame = cw.frame
			cw.floor = GetTime()
			ns.castWatch.armed = true
		end
	end

	-- What became of the last favour once the ledger hears it ended: Queue.lua's
	-- TellLedger tells this first. Only a favour left owed moves on.
	function ns.FavourFate(event, name, arg)
		local last = ns.lastFavour
		if not last or last.fate ~= "owed" or type(name) ~= "string" or last.name ~= name then return end
		if event == "Settled" and arg then
			last.fate = "returned"
		elseif event == "LetGo" then
			last.fate = (arg == "covered" and "covered") or (arg == "never" and "never") or "expired"
		end
		last.endedAt = GetTime()
	end

	-- One slot of your own aura list: the aura, and whether the client provably
	-- refused it. A throw or a secret is a refusal; a plain nil is an empty slot
	-- and possibly a refusal too, so this reports proof of a refusal, never
	-- honesty, and the scan reads the walk as a whole. The pcall stays: the
	-- client restricts this read per aura, and a restricted read can throw.
	--
	-- The forty slots of the walk are read together first (PrefetchSlots), in
	-- one protected call rather than forty: the first slotsTaken of them wait in
	-- slotReads, and a slot past that, after a read that threw, is asked on its
	-- own as ever. Nothing is compared here; a secret waits as it came.
	local slotReads, slotsTaken = {}, 0
	local function PrefetchSlots()
		slotsTaken = 0
		local read = C_UnitAuras.GetAuraDataByIndex
		for index = 1, 40 do
			slotReads[index] = read("player", index, "HELPFUL")
			slotsTaken = index
		end
	end

	-- The walk's first step. A read that throws leaves the slots before it taken
	-- and the slot it threw at filed as a thing that is no aura (false), which
	-- ReadAuraSlot reads as a refusal: asked again it would throw again, a
	-- failure each, so it is not. The slots after it are asked on their own.
	local function TakeSlots()
		if pcall(PrefetchSlots) then return end
		slotsTaken = slotsTaken + 1
		slotReads[slotsTaken] = false
	end

	local function ReadAuraSlot(index)
		local ok, value = true, slotReads[index]
		if index > slotsTaken then ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL") end
		if not ok then return nil, true end
		-- A secret first, before anything compares it: comparing one throws,
		-- and out here that throw would end the walk rather than mark a slot.
		if issecretvalue and issecretvalue(value) then return nil, true end
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
	-- reused, so the spell is compared too. Where the previous reading did not
	-- show it (the one scan of grace the prune gives a vanished aura), or after a
	-- doubted reading of nothing (the last buff ran out, or death took them all),
	-- the ending decides: a cast that ran out and was replaced under its own
	-- number ends later, while a refusal handed back returns the same ending. An
	-- ending missing or unreadable at either end claims nothing and leaves the
	-- aura filed. One the previous reading showed is new when its end moved
	-- RECAST_GAIN or more past the end that reading saw: somebody cast it on
	-- you again, either on top of it while it still ran (a top-up, a favour like
	-- a buff that was not there; asked on CurseForge, 1.11.15, where the /thank
	-- seemed to come only now and then) or after it ran out, between two ticks
	-- of a fight, whose aura events only mark a walk due (UNIT_AURA, below). A
	-- smaller move is the client restating the end, not a cast. An end of 0 is
	-- a buff with none, which never runs out.
	local RECAST_GAIN = 3
	local function IsNew(instanceId, key, expires)
		local known = knownAuras[instanceId]
		if known == nil or known ~= key then return true end
		-- The end compared first: on nearly every slot it is the one last read.
		local before = lastUntil[instanceId]
		if before and expires and before > 0 and expires >= before + RECAST_GAIN
			and lastPresent[instanceId] == key then
			return true
		end
		if not sinceEmpty and lastPresent[instanceId] == key then return false end
		local was = knownUntil[instanceId]
		return (was ~= nil and expires ~= nil and expires > was) or false
	end

	-- A new aura from another player that the class-buff filter drops (Only class
	-- buffs count as favours is on) leaves a line on the trail, once a spell a
	-- session: trail only, so a report shows why no favour came.
	local droppedSaid, droppedCount = {}, 0
	local function NotClassBuff(id, aura)
		if ns.ALL_BUFF_IDS[id] or ns.IsOwnAura(id) or ns.NOT_FAVOUR_IDS[id] then return end
		if plain(aura.isFromPlayerOrPlayerPet) ~= true then return end
		local src = plain(aura.sourceUnit)
		if src == "player" or src == "pet" then return end
		if droppedSaid[id] then return end
		droppedCount = droppedCount + 1
		if droppedCount > 64 then wipe(droppedSaid) droppedCount = 1 end
		droppedSaid[id] = true
		ns.Trail("favour", ("a new buff on you (spell %s) from another player is not a class buff, so it is no favour (Only class buffs count as favours is on)"):format(tostring(id)))
	end

	-- `asked` is UNIT_AURA out of a fight, where a change to your auras walks at
	-- once; the walk a fight's changes left due (ns.FlushOwnScan) is theirs too.
	-- A login's walk and the settle timer's ask for none.
	function ns.ScanOwnBuffs(asked)
		wipe(present)
		wipe(presentUntil)
		-- Read before it is cleared, for the count below.
		asked = asked or ns.ownScanDue
		-- Whatever asked for this reading, a walk a fight's events left due
		-- (ns.FlushOwnScan) is answered by it too.
		ns.ownScanDue = false

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
		-- A walk of all forty slots from here on, counted for /manners debug only when
		-- a change asked for it: a login's and the settle timer's would outnumber the
		-- changes they are set beside.
		if asked then scan.walks = scan.walks + 1 end

		-- Read before the walk, which may set the flag itself further down.
		local primed = auraScanPrimed

		local db = addon.db and addon.db.profile
		local classOnly = not db or db.sources.owedClassBuffsOnly ~= false
		-- Whether anything read now could become a debt or a /thank at all; if
		-- not, no caster is read (four unit lookups per slot, on every UNIT_AURA).
		-- The /thank alone reads nobody in a fight or on the walk made as it
		-- ends: it refuses both (Held), and a favour it skipped is never thanked.
		local watching = primed and db and db.enabled
			and (db.sources.owed or ((db.prompt.thankEmote or db.prompt.thankWhisper)
				and not InCombatLockdown() and not walkAfterFight)) and true or false

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
		TakeSlots()
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
					-- A baseline primed in a fight (a /reload or login into one)
					-- holds what was worn as `true`. The same instance id with its
					-- spell now readable is that aura, so it is filed under its
					-- spell: IsNew then judges it by its end, and an end later than
					-- the one filed is a recast and still new. (A buff that landed
					-- in the fight was filed by the rule above, not primed, and is
					-- still announced once its spell reads.)
					if spellId and primedBlind[instanceId] and knownAuras[instanceId] == true then
						primedBlind[instanceId] = nil
						knownAuras[instanceId] = spellId
					end
					present[instanceId] = key
					presentUntil[instanceId] = expires
					if IsNew(instanceId, key, expires) then
						fresh = fresh or {}
						fresh[#fresh + 1] = instanceId
						-- Who cast it, read while the token still means them, and
						-- only for an aura that could ever be announced.
						-- A class's own aura or aspect reaching you (another
						-- paladin's Devotion Aura, a hunter's Trueshot) is
						-- nobody's favour, whatever the setting: it lands again
						-- every time you walk back into its range. Party auras
						-- in no family (retail's paladin auras, a druid's
						-- Leader of the Pack) are NOT_FAVOUR_IDS. An Earth
						-- Shield cast on you is no aura (Buffs.lua, IsOwnAura).
						if watching and spellId and not ns.IsOwnAura(spellId)
							and not ns.NOT_FAVOUR_IDS[spellId]
							and (not classOnly or ns.ALL_BUFF_IDS[spellId]) then
							Sight(instanceId, key, aura)
						elseif watching and spellId and classOnly then
							NotClassBuff(spellId, aura)
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
					primedBlind[instanceId] = key == true or nil
				end
				auraScanPrimed = true
				scan.primed = true
			else
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
					primedBlind[instanceId] = nil
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
						primedBlind[instanceId] = nil
						local seen = sighted[instanceId]
						-- The name read with the slot is the only one there will be;
						-- a sighting that read nobody ends here, never asked again of
						-- a token that may have changed hands. `filed` lives on the
						-- sighting because an aura that came back under its own
						-- number is in the baseline already. The claim covers the
						-- combat log having seen the same landing with no number:
						-- then the debt is the log's, and the /thank still this one's.
						if seen and seen.key == key and seen.name and not seen.filed then
							seen.filed = true
							NoteFavour(seen, ClaimFavour(seen.name, key))
						elseif seen and seen.key == key and seen.unseen and not seen.filed then
							-- Plainly nobody behind it: no debt and no line, and a
							-- thank with no name while its switch is on. One landing,
							-- one sighting: a later reading never names somebody here.
							seen.filed = true
							ThankNobody(seen)
						end
						-- The game named nobody: the casts seen around the landing may
						-- (AwaitCaster), once the moment they could fall in has passed.
						if seen and seen.key == key and seen.awaitCast and not seen.name and not seen.parked then AwaitCaster(seen) end
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
		-- With the ends it read, so a refresh moves what the next reading
		-- measures a recast against (IsNew).
		wipe(lastUntil)
		for instanceId, expires in pairs(presentUntil) do lastUntil[instanceId] = expires end
		haveLastScan = true
		sinceEmpty = false

		-- The price of never guessing what a refusal looks like (STATUS.md): a
		-- refusal that repeats identically across two scans is indistinguishable
		-- from holding nothing, and is left as it is. Likewise a buff landing
		-- between the first true reading and the one corroborating it is filed as
		-- already carried and never announced -- better unheard than filed against
		-- a bystander. The settle timer keeps that gap at SETTLE_INTERVAL, or at
		-- SETTLE_SLOW_INTERVAL once a refusal has outlasted the fast stage. A scan
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
	-- the only source on Forever. The log adds what the scan cannot:
	-- SPELL_AURA_APPLIED carries the caster's GUID, and GetPlayerInfoByGUID names a
	-- stranger with no unit token. A log line is an event, not a reading, so none
	-- of the scan's corroboration applies; NoteFavour's policy gates still do.
	---------------------------------------------------------------------------

	-- What this source has made of itself, for /manners debug, as ns.auraScan.
	ns.logScan = { armed = false, applied = 0, noted = 0 }

	-- Where the reading lives. Classic Era 1.15.9, TBC 2.5.6 and Mists 5.5.4
	-- all moved it to C_CombatLog.GetCurrentEventInfo and keep the old global
	-- only in Blizzard_DeprecatedCombatLog, which loads with the
	-- loadDeprecationFallbacks setting and is gone without it -- and then
	-- every line threw, and the log was armed and read nothing. The global only
	-- where the namespace is missing.
	local function CombatLogEvent()
		local log = _G.C_CombatLog
		local read = type(log) == "table" and log.GetCurrentEventInfo
		if type(read) ~= "function" then read = _G.CombatLogGetCurrentEventInfo end
		if type(read) ~= "function" then return end
		return read()
	end

	-- A line that has passed the handler's two questions (below), handed the
	-- rest of what it needs from the reading the handler made: the client is
	-- asked for a line once.
	local function ReadCombatLogFavour(sourceGUID, destGUID, spellId)
		-- Landed on us, and not by our own hand.
		destGUID, sourceGUID = plain(destGUID), plain(sourceGUID)
		if destGUID == nil or destGUID ~= playerGUID then return end
		if sourceGUID == nil or sourceGUID == playerGUID then return end

		-- Asked here too so a switched-off source does no per-event work;
		-- NoteFavour's check is the gate. People who buff me alone, not the
		-- /thank: a log line has no token to thank at, and the aura scan thanks
		-- for every landing it reads, whichever source filed the debt.
		-- Or the whisper by name, for somebody no token holds (ThankByName), with
		-- Thank them even when I can't see who it was on beside it.
		local db = addon.db and addon.db.profile
		if not db or not db.enabled then return end
		if not db.sources.owed and not (db.prompt.thankUnseen == true and db.prompt.thankWhisper == true) then
			return
		end

		spellId = plain(spellId)
		if spellId == nil then return end
		-- The aura scan's filter, from the same setting: every class's buffs, since
		-- the buff a stranger puts on you is one of theirs.
		if db.sources.owedClassBuffsOnly ~= false and not ns.ALL_BUFF_IDS[spellId] then
			return
		end
		-- Nor a class's own aura, as the aura scan has it.
		if ns.IsOwnAura(spellId) or ns.NOT_FAVOUR_IDS[spellId] then return end

		ns.logScan.applied = ns.logScan.applied + 1

		-- A name and a class out of a GUID, with no unit token: the reason this
		-- source exists. It answers nothing for an NPC, a pet or a totem, so it
		-- doubles as the is-a-player check without reading possibly withheld flags.
		if type(GetPlayerInfoByGUID) ~= "function" then return end
		local _, class, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)
		-- The aura scan's join, so both sources file one person under one key.
		local full = JoinName(plain(name), plain(realm))
		-- Somebody on your /ignore list, as the aura scan asks it (Sight): no
		-- debt, no line, nothing offered back. By name and by GUID, the two
		-- this source has where Sight has a token; ahead of the claim, so the
		-- scan, which drops them too, is not left a mark to consume.
		if ns.Ignored(full, sourceGUID) then return end
		if not full then return end

		if not ClaimFavour(full, spellId) then return end
		ns.logScan.noted = ns.logScan.noted + 1
		-- The shape Sight produces, so NoteFavour has one kind of record; with
		-- no token in it, it is never thanked from here.
		NoteFavour({ key = spellId, name = full, guid = sourceGUID, class = plain(class) }, true)
	end

	function addon:COMBAT_LOG_EVENT_UNFILTERED()
		-- Cheapest questions first: every swing, tick and proc within fifty yards
		-- arrives here, and most cost two string compares. Asked ahead of the
		-- guard, of the client's own reading (CombatLogEvent type-checks what it
		-- calls, and nothing after it throws), so those lines cost no protected
		-- call; a line of the one kind this source reads goes on, guarded.
		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, _, _, auraType = CombatLogEvent()
		if plain(subevent) ~= "SPELL_AURA_APPLIED" then return end
		if plain(auraType) ~= "BUFF" then return end
		-- Guarded: an unguarded handler that throws simply stops being a source.
		ns.Guard("combat log", ReadCombatLogFavour, sourceGUID, destGUID, spellId)
	end
end

-- Whether UNIT_AURA on you has asked for a walk of your aura list that nothing
-- has made yet. Set only in a fight, or while the client keeps auras secret
-- (UNIT_AURA, below); cleared by any walk (ScanOwnBuffs).
ns.ownScanDue = false

-- The walk a fight's aura events left due, made now: on the tick (Core.lua,
-- TickBody), ahead of what Automatic remembers and the repaint, and when the
-- fight ends, ahead of the repaint that takes the combat hold off.
function ns.FlushOwnScan()
	if not ns.ownScanDue then return end
	-- Only a fight marks the walk due, or the secret aura events a keystone or a
	-- PvP match sends between its fights (UNIT_AURA, below), so out of lockdown
	-- this is a fight's end or a lull in one of those, and what the walk finds
	-- is kept as quiet as the fight's (walkAfterFight, above).
	walkAfterFight = not InCombatLockdown()
	ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs)
	walkAfterFight = false
end

function addon:UNIT_AURA(_, unit, info)
	-- Retail 12.1 makes the whole payload secret while auras are secret (a
	-- fight, an encounter, a keystone, a PvP match), and a secret may be neither
	-- compared nor handed to UnitGUID: either is a Lua error from addon code,
	-- outside any Guard. Whose auras changed cannot be told, so they may be
	-- yours: the walk is marked due as a fight marks it, counted once for that
	-- walk (most are somebody else's), and nobody is forgotten, since a reading
	-- lasts three seconds anyway (Core.lua, UnitHasBuff).
	unit = plain(unit)
	if unit == nil then
		if not ns.ownScanDue then ns.auraScan.events = ns.auraScan.events + 1 end
		ns.ownScanDue = true
		ns.ownAurasChanged = true
		return
	end

	if unit == "player" then
		ns.auraScan.events = ns.auraScan.events + 1
		if InCombatLockdown() then
			-- A walk is forty slots behind one protected call, and a fight sends this many
			-- times a second: the walk waits for the next tick (the Advanced tab's scan
			-- interval, 0.4 s by default), so a burst costs one. A favour that lands in
			-- the fight is said up to that much later, and filed all the same.
			ns.ownScanDue = true
		else
			-- Out of a fight at once: the events are few, and a favour's line
			-- comes as the buff lands. Asked for by this change, so counted.
			ns.Guard("ScanOwnBuffs", ns.ScanOwnBuffs, true)
		end
		-- Read on the next tick rather than here: a fight fires this on you
		-- many times a second (Core.lua, RememberOwnBuffs).
		ns.ownAurasChanged = true
	end

	-- Keyed by GUID, never the unit token: nameplate tokens are recycled.
	ForgetUnitAuras(plain(UnitGUID(unit)))
	-- And what was read of their debuffs, once anything has been (Cures.lua).
	if ns.cureReads then ns.ForgetCureRead(unit) end
	-- And a refusal remembered on them, while one is (Queue.lua, AuraChangedOn):
	-- a buff added to them or taken off is something changed.
	if ns.refusalWatch then ns.AuraChangedOn(unit, info) end
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
	-- The bar macro, parked at the last loading screen, follows the prompt
	-- again (Clicks.lua, click macro).
	if ns.UnparkMacroBody then ns.Guard("bar macro", ns.UnparkMacroBody) end
end

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
	if unit then ns.nameplateUnits[unit] = true end
end

function addon:NAME_PLATE_UNIT_REMOVED(_, unit)
	if unit then ns.nameplateUnits[unit] = nil end
end
