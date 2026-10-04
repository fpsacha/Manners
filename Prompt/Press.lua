-- Manners -- a press on the prompt: PreClick aims the macro at the last
-- moment, PostClick files what the press was.
--
-- Both are set on the button by Create (Panel.lua) from Button.lua's list, and
-- are written out rather than inside Create: Lua 5.1 allows a function 60
-- upvalues, a closure's count against the function it sits in, and written
-- inline they took Create() past the limit, so the prompt failed to load at
-- all (beta.6).

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local NoteVerdicts, Retired, LightFuse = lib.NoteVerdicts, lib.Retired, lib.LightFuse

-- When each handler last took a press: one press delivers a down and an up,
-- and each is counted once.
local lastClickAt, lastPreClickAt, lastSkipAt
-- Its own stamp rather than one of the three above: the refusal it rate-limits
-- happens on presses none of those are counting.
local lastStaleAt

-- What the last resolved press left on the button. The debounce may skip
-- re-resolving only while the button still holds this.
local pressKey
-- Whether the press being resolved is on somebody the fresh queue no longer
-- holds (the hold or the empty-queue fuse kept them). Their entry's range
-- reading is from a scan the latest one overruled, so it says nothing about
-- whether a shout reached them. Set in PreClick, read and cleared in PostClick.
local pressStale

-- How many names PostClick has written into ns.lastGave since it was last
-- emptied.
local lastGaveCount = 0
local LAST_GAVE_CAP = 400

-- The moment of a press the cooldown turned away, stamped in PreClick and
-- consumed by PostClick in the same frame. Stamped ahead of the combat return:
-- in a fight only the bookkeeping can be refused.
local cooldownPressAt
-- ...and what the button held when the guard disarmed it, so PostClick can put
-- it back; left disarmed, a fight starting before the next scan froze the
-- prompt empty.
local guardedEntry
-- ...and the spoken line it carried, put back with it so the tooltip and the
-- next press quote the same roll.
local guardedPhraseKey, guardedPhraseText, guardedPhraseSource

-- The one question the click path asks. Deliberately not Core's "is the addon
-- switched on", which governs bookkeeping; this governs whether the button in
-- front of somebody should fire.
local function PromptIsLive()
	local db = ns.db and ns.db.profile
	if not db or not db.enabled then return false end
	-- Unlocked is drag mode, and a prompt being dragged must not cast.
	if not db.prompt.locked then return false end
	if S.testMode then return false end
	-- Belt and braces: BuildQueue already returns nothing with nothing to
	-- cast, so no mutation of this line can go red. It keeps the click path
	-- stating the same condition the panel does.
	if not ns.CanCastAnything() then return false end
	return true
end

-- The spell the press casts, by id, for the client's word on whether it can
-- go now: a group cast's own, else the best rank learned, as the queue asks.
local function PressSpell(entry)
	if entry.groupCast and entry.groupCast.spell then return entry.groupCast.spell end
	local info = ns.BuffInfo(entry.buff)
	return (info and info.topRank) or (entry.buff.ranks and entry.buff.ranks[1])
end

-- Whether PreClick leaves the spoken line out of this press. A macro runs
-- every line even when its /cast fails, and a line said cannot be taken back
-- (beta.8: two thank-yous, no buff; then "The Light already likes you,
-- Weirbeard Jenkins" over "Out of range."). So out of combat the line goes in
-- only for a press known to land -- "if I can't buff someone, I should not
-- say anything" -- and anything the client will not answer is a no:
--   - not turned down by the scan PreClick has just made (`verdicts`, its
--     second return): the hold and the fuse still press somebody it found
--     covered, dead or out of reach since, or with everybody refused for
--     your own state (dead, on a taxi). "far" is only the nearness check;
--   - a token naming them now (ns.UnitFor): a remembered passer-by or a
--     tokenless favour has none, and the scan's token may name somebody else;
--   - alive: the hold and the fuse keep somebody a moment after they die, and
--     a range check measures distance, not life;
--   - in reach, asked as the scan asks it (ns.ReachNow), and for a shout
--     surely inside its own radius (ns.ShoutSure): the scan's reach for a
--     shout is looser than the shout on purpose;
--   - the global cooldown, your own cast and the spell's own cooldown over;
--   - the spell usable, mana included, where the client says.
-- Line of sight no call can tell. The press itself goes out either way, and
-- the line rolled for them is kept (ApplyTarget re-rolls only for somebody
-- new), so a press that lands says it.
local function HoldLine(entry, verdicts)
	local speech = ns.db and ns.db.profile.speech
	-- Nothing to say, so nothing to judge, and no tokens walked.
	if not (speech and speech.enabled) then return false end
	if not (entry and entry.buff and entry.name) then return true end
	-- A line to them in the last minute (Macro.lua, ns.LineRested), as the
	-- arming asks it, so the tooltip and the press agree.
	if not ns.LineRested(ns.LineSpeaker(entry), GetTime()) then return true end
	if verdicts == true or (type(verdicts) == "table" and verdicts[entry.name] == true) then return true end
	local unit = ns.UnitFor(entry.name, entry.unit)
	if not unit then
		-- With friendly nameplates off a passer-by seldom has a token: said
		-- once a session (Speech.lua).
		ns.NoteTokenlessHold(entry)
		return true
	end
	local deadOrGhost = _G.UnitIsDeadOrGhost
	if type(deadOrGhost) ~= "function" or ns.plain(deadOrGhost(unit)) ~= false then return true end
	if ns.ReachNow(unit, entry.buff) ~= true then return true end
	if entry.buff.selfCast and ns.ShoutSure(unit) ~= true then return true end
	local spell = PressSpell(entry)
	if not ns.CastReady(spell) then return true end
	local usable = C_Spell and C_Spell.IsSpellUsable
	if type(usable) ~= "function" then usable = _G.IsUsableSpell end
	-- Through safecall: the call's shape differs between client generations.
	if spell and ns.safecall(usable, spell) == false then return true end
	return false
end

-- PreClick runs before the secure handler reads the attributes, so out of
-- combat the target is re-resolved at the last moment: a nameplate token may
-- since have been recycled to somebody else. Every mouse button
-- arrives ("AnyDown"); only the left one casts.
local function OnPreClick(self, mouseButton)
	if mouseButton and mouseButton ~= "LeftButton" then return end
	local now = GetTime()
	-- The macro's own /target and hand-back are not the player choosing
	-- anybody; Core's PLAYER_TARGET_CHANGED ignores changes this close to it.
	ns.pressAt = now

	-- Asked before the combat return: in combat the frozen macro still goes
	-- out, and the bookkeeping can still be refused where the macro cannot.
	local ready, left = ns.CastReady()
	-- In combat a press late in the cooldown is queued by the client, so it
	-- counts as ready. Out of combat the whole cooldown is held back: a queued
	-- /cast would fire after /targetlasttarget.
	if InCombatLockdown() and not ready and left <= ns.SpellQueueWindow() then
		ready = true
	end
	-- Then the combat return: in combat nothing below can change the macro,
	-- since the attributes are frozen, so neither the target nor the spoken
	-- line (range, a refusal) is looked at again until the fight ends.
	cooldownPressAt = (not ready) and now or nil
	if InCombatLockdown() then
		pressStale = nil
		return
	end

	-- Down and up both land here; one rebuild per press, but only while the
	-- button still holds what that rebuild armed (an error or a cooldown in
	-- between can change it).
	if lastPreClickAt and (now - lastPreClickAt) < 0.25 then
		if not ready then
			guardedEntry = S.current
			guardedPhraseKey, guardedPhraseText, guardedPhraseSource = S.phraseKey, S.phraseText, S.phraseSource
			Prompt:ApplyTarget(nil)
		elseif S.appliedKey ~= pressKey then
			Prompt:ApplyTarget(nil)
		end
		return
	end
	lastPreClickAt = now
	pressKey = nil
	pressStale = nil

	-- A keypress on an empty prompt says why it is empty, or it looks like a
	-- broken binding. Commands and option names go in as arguments: they are
	-- not translated.
	if not self:IsShown() then
		local db = ns.db and ns.db.profile
		if db and not db.enabled then
			ns.addon:Print(L["Manners is |cffff8080switched off|r -- %s to start again."]
				:format("|cffffd100/manners on|r"))
		elseif ns.SnoozeLeft(now) then
			ns.addon:Print(L["Manners is snoozed until %s -- %s brings the prompt back now."]
				:format(ns.SnoozeEndsAt(), "|cffffd100/manners snooze off|r"))
		elseif ns.HiddenWhileMounted() then
			ns.addon:Print(L["the prompt stays away while you are mounted -- get off, or switch off %s on the %s tab."]
				:format("|cffffd100" .. L["Hide the prompt while I'm mounted"] .. "|r", L["When to offer"]))
		elseif not ns.CanCastAnything() then
			local class = ns.caps.class
			if class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
				ns.addon:Print(ns.NO_CLASS_BUFFS)
			else
				ns.addon:Print(L["nothing learned to cast yet."])
			end
		elseif ns.SavingMana() then
			-- The option goes in by its own key, so a translation names the
			-- label the window shows.
			local _, resume = ns.SavingMana()
			-- Your own buff is kept while saving (Queue.lua, SelfEntry), so the
			-- sentence names it wherever "Myself" is on.
			local line = ns.OffersSelf()
				and L["nobody to buff right now -- saving mana until you are back to %d%%, so only your own buff and people who buffed you or asked are offered. The floor is %s on the %s tab."]
				or L["nobody to buff right now -- saving mana until you are back to %d%%, so only people who buffed you or asked are offered. The floor is %s on the %s tab."]
			ns.addon:Print(line:format(resume, "|cffffd100" .. L["Save mana: stop below (% mana)"] .. "|r", L["When to offer"]))
		else
			ns.addon:Print(L["nobody to buff right now."])
		end
		Prompt:ApplyTarget(nil)
		return
	end

	-- PreClick is the last chance to stop an unlocked or disabled prompt
	-- casting.
	if not PromptIsLive() then
		Prompt:ApplyTarget(nil)
		return
	end

	-- Nor during the global cooldown: disarmed here, the press never reaches
	-- the server to be refused. Its stamp is taken back so the next press
	-- resolves.
	if not ready then
		lastPreClickAt = nil
		guardedEntry = S.current
		guardedPhraseKey, guardedPhraseText, guardedPhraseSource = S.phraseKey, S.phraseText, S.phraseSource
		Prompt:ApplyTarget(nil)
		Prompt:SayWaiting(left)
		return
	end

	local queue, verdicts = ns.BuildQueue(S.hovering)
	NoteVerdicts(verdicts)
	local top = Prompt:PickTop(queue, queue[1])
	S.pickedFrom = queue
	local named = Prompt:PanelName()
	-- An empty queue under a panel still naming somebody: the press agrees with
	-- the screen (at worst the game refuses the cast, in red) rather than
	-- silently doing nothing. Not for somebody retired, and not under a flash
	-- about somebody else: the press follows the words on the panel.
	if not top and S.current and not Retired(S.current, now) and named == S.current.name then
		LightFuse(now)
		pressStale = true
		-- Re-keyed rather than rebuilt: whether the macro hands your target back
		-- depends on who is targeted now, which can have changed since the
		-- repaint that armed it. Whether the line goes is judged again too:
		-- this entry's reading is the oldest there is.
		Prompt:ApplyTarget(S.current, HoldLine(S.current, verdicts))
		pressKey = S.appliedKey
		return
	end

	-- The press goes to whoever the panel names, not whoever the queue just
	-- promoted: PickTop hands the panel to somebody strictly better at once,
	-- which is right for the next repaint and wrong for a press made on this
	-- one.
	if top and named and top.name ~= named then
		local fresh
		for _, candidate in ipairs(queue) do
			if candidate.name == named then fresh = candidate break end
		end
		if not fresh then
			Prompt:MovedOn(top)
			return
		end
		top = fresh
	end

	-- A held entry is not in the queue it was just picked against.
	if top then
		pressStale = true
		for _, candidate in ipairs(queue) do
			if candidate.name == top.name then pressStale = nil break end
		end
	end

	S.appliedKey = nil
	-- A held entry's range reading is from an overruled scan, and even a fresh
	-- one is a tick old, so whether the line goes is judged once more right
	-- before the macro runs.
	Prompt:ApplyTarget(top, HoldLine(top, verdicts))
	pressKey = S.appliedKey
end

local function OnPostClick(self, mouseButton, down)
	-- Bookkeeping only, and switched off, unlocked or previewing there is none:
	-- a CLICK binding reaches a hidden frame. In combat the frozen macro may
	-- still have cast; the debt stands and the line says so.
	local db = ns.db and ns.db.profile
	if not PromptIsLive() then
		local now = GetTime()
		-- Only a press that could have cast gets the warning: type2 to type5
		-- are "none", so the right button casts nothing. A keybinding arrives
		-- with no button and counts as a left press, as in the cast path below.
		local couldCast = mouseButton == nil or mouseButton == "LeftButton"
		if couldCast and db and db.verbose and InCombatLockdown() and self:GetAttribute("macrotext1")
			and not (lastStaleAt and (now - lastStaleAt) < 0.25) then
			lastStaleAt = now
			ns.addon:Print(L["|cffff8080that may still have cast|r -- the prompt cannot be disarmed in combat, and nothing was recorded for it."])
		end
		return
	end

	-- A right-press says "not this one": the debt stands, nothing is cast, and
	-- the offer is postponed. The block is on the person, not the buff.
	if mouseButton == "RightButton" then
		-- Its own stamp: sharing the cast path's would let a right-press
		-- swallow a real left click landing just after it.
		local now = GetTime()
		if lastSkipAt and (now - lastSkipAt) < 0.25 then return end
		lastSkipAt = now
		-- Whoever the panel names, as the left press follows: under a red flash
		-- that is the person the flash is about, not the next one armed
		-- underneath.
		local victim = Prompt:PanelName() or (S.current and S.current.name)
		if not victim then
			ns.addon:Print(L["nobody to skip right now."])
			return
		end
		local db = ns.db and ns.db.profile
		-- The retry cooldown, not the two seconds a failed cast writes:
		-- that would put them straight back on the prompt.
		ns.BlockPerson(victim)
		-- A group cast on the panel: the skip is of the whole party, or the
		-- cast re-forms around the next of them on the next scan.
		local group = S.current and S.current.name == victim and S.current.groupCast and S.current or nil
		if group and ns.SkipGroupCast then ns.SkipGroupCast(group) end
		-- Your own buff, by the name rather than the entry: under the flash
		-- of a press on yourself the entry armed may already be the next one.
		local own = ns.IsPlayerName(victim)
		Prompt:StopAttention()
		-- "Never" for yourself is the switch (StopOfferingSelf): the list is
		-- of other people, and every line it says is about somebody else.
		if IsShiftKeyDown and ns.plain(IsShiftKeyDown()) and own then
			ns.StopOfferingSelf()
			ns.Guard("own buff repaint", Prompt.Refresh, Prompt)
			return
		end
		-- Held shift makes it "never": onto the never-offer list. Nothing here
		-- touches the button (type2 is "none"), so it is as safe in a fight as
		-- the skip. The block above still matters: it takes them off the panel
		-- now, not after the hold and the fuse. The list itself reaches the
		-- queue at its next rebuild, which in a fight is when the fight ends.
		if IsShiftKeyDown and ns.plain(IsShiftKeyDown()) then
			-- The repaint comes with the listing: see the wrapper beside
			-- Prompt:Refresh (Refresh.lua). Only the person the cast was aimed
			-- at is listed, which the listing's own line names; the rest are
			-- skipped.
			ns.PutOnNeverList(victim)
			if group and db and db.verbose then
				ns.addon:Print(L["The rest of %s is skipped for now."]:format(group.groupCast.label or "?"))
			end
			return
		end
		-- In a fight the macro stays frozen on `current` and the next press
		-- still casts at them, so a skip of that person says so, verbose or
		-- not, as the menu's skip does. Asked of `current`, not the panel: under
		-- a flash about somebody else the plain line is the true one. Not for
		-- your own buff: a held press there only casts it on you.
		local frozenOnThem = not own and InCombatLockdown() and S.current and S.current.name == victim
		if db and db.verbose and own then
			ns.addon:Print(L["skipping your own buff for now."])
		elseif frozenOnThem or (db and db.verbose) then
			local shown = (group and group.groupCast.label)
				or (S.current and S.current.name == victim and S.current.short)
				or (ns.ShortName and ns.ShortName(victim)) or victim
			ns.addon:Print((frozenOnThem
				and L["skipping |cffffffff%s|r for now -- but the prompt cannot move off them in a fight, and a press still casts at them."]
				or L["skipping |cffffffff%s|r for now."]):format(shown))
		end
		-- The panel moves on now rather than at the next scan, so a left press
		-- cannot cast at the person just declined. Refresh knows about the
		-- fight.
		ns.Guard("skip repaint", Prompt.Refresh, Prompt)
		return
	end
	if mouseButton and mouseButton ~= "LeftButton" then return end

	local now = GetTime()
	-- A press the cooldown turned away is not a press: nothing is filed. Out of
	-- combat this puts back what PreClick disarmed.
	if cooldownPressAt == now then
		cooldownPressAt = nil
		local found = guardedEntry
		guardedEntry = nil
		if found and not InCombatLockdown() then
			-- The line it carried goes back with it, so the macro keeps the
			-- roll the tooltip has been quoting.
			S.phraseKey, S.phraseText, S.phraseSource = guardedPhraseKey, guardedPhraseText, guardedPhraseSource
			Prompt:ApplyTarget(found)
		end
		guardedPhraseKey, guardedPhraseText, guardedPhraseSource = nil, nil, nil
		if ns.db and ns.db.profile.debugClicks then
			ns.addon:Print("|cffffd100CLICK|r " .. L["held back -- the cooldown was still running"])
		end
		return
	end

	-- One press delivers both a down and an up; count and settle once.
	if lastClickAt and (now - lastClickAt) < 0.25 then return end
	lastClickAt = now

	-- Lets the error and cast handlers tell our own outcome apart from
	-- everything else the game is shouting about.
	ns.lastClickTime = now
	-- Only assembled when asked for: /manners clicks. The build stamp says
	-- which build produced the log.
	if ns.db and ns.db.profile.debugClicks then
		ns.addon:Print(("|cffffd100CLICK|r build=%s macro=%s"):format(
			tostring(ns.BUILD),
			tostring(R.button:GetAttribute("macrotext1") or "nil"):gsub("%s+", " ")))
	end
	if not (S.current and S.current.name) then return end

	-- The line went out with this press, so "In character" counts it as said
	-- lately now rather than when it was rolled: a roll the press left out
	-- (out of reach, the cursor gone from them) was never heard.
	if S.phraseArmed and S.phraseSource and ns.InCharacter and ns.InCharacter.Remember then
		ns.InCharacter.Remember(S.phraseSource)
	end
	-- ...and the person it went to has had their line for the minute.
	if S.phraseArmed then ns.NoteLineSaid(ns.LineSpeaker(S.current).name, now) end

	-- Park the press rather than clearing the debt: the game says a moment
	-- later whether anything was cast. What the macro was aimed at and the old
	-- rotation pointer ride along. Anything already parked is abandoned first,
	-- since one slot cannot match two records to their events, and before
	-- ns.lastGave is read, because abandoning restores it. And it is read here,
	-- above the rotation write below, the last point it holds the old value.
	ns.AbandonPendingClick()
	-- A held or fused entry's range reading comes from a scan the latest one
	-- overruled, so it answers neither way: the settle keeps the debt as
	-- nothing being able to tell.
	local stale = pressStale
	pressStale = nil
	ns.pendingClick = { name = S.current.name, at = GetTime(),
		buffKey = S.current.buff and S.current.buff.key,
		selfCast = S.armed ~= nil and S.armed.selfCast == true,
		-- Whether the macro that ran carried the spoken line, for a refusal to
		-- tell a press that thanked them from one that went out silent
		-- (Queue.lua, NoteRefusal). A /manners try template is the player's own
		-- text, and may say anything.
		spoke = S.phraseArmed == true or ns.tryMacro ~= nil,
		-- Your own buff: settled with nothing filed (Clicks.lua, SettleSelf).
		-- Read off the entry as well as the record: a /manners try macro arms
		-- no record, and the game naming you as the one it reached would
		-- otherwise file a gift to yourself in the ledger.
		onSelf = (S.armed ~= nil and S.armed.onSelf == true) or S.current.reason == "self",
		targeted = S.armed and S.armed.targeted,
		-- The spelling the macro aimed at, straight from the builder, for the
		-- settle path to compare against whoever the client says was hit.
		aimedAt = S.armed and S.armed.aimedAt,
		-- Whether the scan measured them inside a shout's reach: a selfCast
		-- press clears a debt only where this is true.
		withinShout = S.current.ranged == true and not stale,
		-- ...and outside it, so the line can say the answer was no rather than
		-- that nothing answered.
		outOfShout = (not stale and S.current.ranged == false) or nil,
		-- For the favour ledger only. The reason too: a buff somebody asked
		-- for in chat is listed as asked and left out of the day's gifts
		-- (Ledger.Settled), which it can only tell from the record.
		class = S.current.class,
		inGroup = S.current.inGroup,
		reason = S.current.reason,
		gave = ns.lastGave[S.current.name],
		-- A group cast (GroupBuffs.lua): the spell, and everybody else it
		-- covers, whom the settle repays and the ledger counts with this one.
		group = S.current.groupCast and {
			spell = S.current.groupCast.spell,
			members = S.current.groupCast.members,
			class = S.current.groupCast.class,
			-- Whether everybody it covers asked for it in chat (GroupBuffs.lua):
			-- the ledger files a group cast as asked only then, whatever
			-- `reason` the anchor carries.
			asked = S.current.groupCast.asked,
		} or nil }
	-- A shout lands on everybody in the party close enough to hear it, not
	-- only the one it was aimed at: whoever else the scan measured inside its
	-- reach for the same shout is settled with them (Clicks.lua,
	-- SettleShout). Never yourself, and nobody on an overruled reading.
	if S.armed and S.armed.selfCast and not stale and S.current.buff then
		local names
		for _, entry in ipairs(S.pickedFrom or {}) do
			if entry.name ~= S.current.name and entry.ranged == true and entry.reason ~= "self"
				and entry.buff and entry.buff.selfCast and entry.buff.key == S.current.buff.key then
				names = names or {}
				names[#names + 1] = entry.name
			end
		end
		ns.pendingClick.shoutMembers = names
	end
	-- Everybody the group cast covers waits out the same cooldown as the
	-- person it is aimed at, or they come straight back as single offers
	-- while their auras still read the buff as missing.
	if S.current.groupCast and S.current.buff then
		for _, name in ipairs(S.current.groupCast.members) do
			ns.MarkAttempted(name, S.current.buff.key)
		end
	end
	-- Per buff, so casting Fortitude does not stop the walk reaching
	-- Divine Spirit on the next click.
	if S.current.buff then
		ns.MarkAttempted(S.current.name, S.current.buff.key)
		-- Only where the walk will read it back: a paladin's blessings
		-- overwrite one another, so PickBuffFor never rotates them.
		if ns.RotatesBuffs() then
			-- Bounded like every other per-person table. It is only a rotation
			-- hint for people whose auras cannot be read, so losing an old
			-- pointer costs at most one repeated first buff.
			if ns.lastGave[S.current.name] == nil then
				if lastGaveCount >= LAST_GAVE_CAP then
					wipe(ns.lastGave)
					lastGaveCount = 0
				end
				lastGaveCount = lastGaveCount + 1
			end
			ns.lastGave[S.current.name] = S.current.buff.key
		end
	end
	Prompt:StopAttention()
end

lib.OnPreClick, lib.OnPostClick = OnPreClick, OnPostClick
