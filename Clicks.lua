-- Manners -- what became of a press: the click parked until the game says
-- whether a cast went out, what that settles or rewinds, the global cooldown,
-- and the /click macro the options page offers.

local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L
local addon = ns.addon

local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Queue.lua's, which load first.
local plain, safecall, caps, SpellNameFor = ns.plain, ns.safecall, ns.caps, ns.SpellNameFor
local owed, LiveExpiry, SaveDebts = ns.owed, ns.DebtExpiry, ns.SaveDebts
local TellLedger, ListedAs = ns.TellLedger, ns.ListedAs

---------------------------------------------------------------------------
-- the pending click and its settle
---------------------------------------------------------------------------

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
	-- A group cast blocked everybody it covered; none of them got it either.
	if pending.group then
		for _, name in ipairs(pending.group.members) do
			ns.MarkAttempted(name, pending.buffKey, 2)
		end
	end
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
	-- Nothing reached them, so the spoken line (which the macro ran anyway) is
	-- held; no back-off, since nothing here says the game refused them.
	ns.NoteRefusal(pending.name, nil, true)
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
	ns.NoteRefusal(pending.name, message)
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
ns.SweepPendingClick = SweepPendingClick

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
		local record = settledRecent[i]
		if now - record.at > SETTLE_SECONDS then
			table.remove(settledRecent, i)
			-- Nothing refused it inside the window, so it landed, and whatever the
			-- game refused on this person before is over. Not at the settle
			-- itself: SENT is the client sending, and the refusal that repeats
			-- comes after it.
			if record.landed then ns.NoteLanded(record.name) end
		end
	end
end
ns.PruneSettled = PruneSettled

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

-- Everybody else a group cast covered, on the same evidence as the person it
-- was aimed at: a favour any of them did you is returned by it, whatever they
-- asked for is answered, and they wait out the cooldown. Only the favours go
-- to the ledger, which files the cast itself once, under the anchor. Returns
-- what a late refusal needs to undo it.
local function SettleGroup(pending, spellId)
	local records, repaid = {}, {}
	local covered = { buffKey = pending.buffKey, group = pending.group, inGroup = true }
	for _, name in ipairs(pending.group.members) do
		local debt = owed[name]
		ns.MarkAttempted(name, pending.buffKey)
		if debt then
			ns.SettleFavour(name)
			TellLedger("Settled", name, debt, covered, spellId)
			repaid[#repaid + 1] = ns.ShortName(name)
		end
		ns.ServeRequest(name, pending.buffKey)
		records[#records + 1] = { name = name, owed = debt,
			listedAtSettle = debt ~= nil and ListedAs(name) ~= nil }
	end
	local db = addon.db and addon.db.profile
	if #repaid > 0 and db and db.verbose then
		addon:Print(L["|cffffd100%s|r returned the favour to %s as well."]:format(
			SpellLabel(pending.group.spell), table.concat(repaid, ", ")))
	end
	return records
end

-- A late refusal of a group cast: the favours it returned are owed again, as
-- the anchor's is, and the ledger takes back each by the settle's clock.
local function UnsettleGroup(settled)
	for _, member in ipairs(settled.members or {}) do
		if member.owed then
			TellLedger("Refused", member.name, settled.at)
			if not member.listedAtSettle and ListedAs(member.name) then
				-- Listed since: let go, as the anchor's is (see below).
				TellLedger("LetGo", member.name, "never")
			else
				local standing = owed[member.name]
				if not standing or LiveExpiry(standing) < LiveExpiry(member.owed) then
					owed[member.name] = member.owed
				end
			end
		end
	end
	SaveDebts()
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
		-- The macro's line thanked them for a buff that went elsewhere or never
		-- went, so it is held; no back-off, since the game refused nobody.
		ns.NoteRefusal(pending.name, nil, true)
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
	if not unheard then ns.ServeRequest(pending.name, pending.buffKey) end
	-- The ledger follows the same gate as the debt.
	if not unheard then TellLedger("Settled", pending.name, wasOwed, pending, spellId) end
	-- A group cast settles everybody else it covered with the same evidence.
	-- A shout is never one, so `unheard` cannot be true here.
	local members = pending.group and SettleGroup(pending, spellId) or nil
	-- The client sent the cast; the server has not answered yet. Keep the
	-- record so a refusal arriving a moment from now has something to be about.
	-- Whether they were on the never-offer list already, which a favour owed
	-- ignores (STATUS.md); only a listing after the settle lets it go.
	RememberSettled({ name = pending.name, buffKey = pending.buffKey,
		gave = pending.gave, at = GetTime(), owed = wasOwed, castGUID = castGUID,
		listedAtSettle = ListedAs(pending.name) ~= nil,
		-- A shout nothing measured them inside of is not a cast on them.
		landed = not unheard,
		group = pending.group, members = members })
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

	-- Everybody else a group cast covered, whichever way the anchor goes
	-- below; RewindClick puts back their cooldowns with the anchor's.
	if settled.members then UnsettleGroup(settled) end

	-- A shift-right-click since the settle let this favour go, and a refusal
	-- must not bring it back: owed people are exempt from the list. The row
	-- goes from returned back to let go, and nothing claims a debt still kept.
	local listed = settled.owed and not settled.listedAtSettle and ListedAs(settled.name)
	if listed then
		TellLedger("Refused", settled.name, settled.at)
		TellLedger("LetGo", settled.name, "never")
		RewindClick(settled)
		return settled.name
	end

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
	-- This is the refusal that repeats for somebody the game will never let
	-- you buff (beta.8): every press settles on SENT and comes back here.
	ns.NoteRefusal(settled.name)
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
	-- After the line above, which hands its refusal the words itself; this is
	-- for a refusal that arrived first, with none (UNIT_SPELLCAST_FAILED).
	ns.NoteGameError(message)
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
