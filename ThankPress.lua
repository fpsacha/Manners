-- Manners -- Ask me before thanking (prompt.thankAsk, off): a thank-you that
-- waits for a press of the prompt instead of going out by itself.
--
-- Asked for on CurseForge: a thank sent the moment a buff lands does not feel
-- personal, and a press of your own adds that touch. With this on, a favour
-- Favours.lua would have thanked at once (the /thank emote, the whispered
-- thank-you, or both, exactly as the player set them up) is parked here
-- instead, and the prompt offers "Thank <name>". A press, by the mouse or the
-- prompt's key, sends what would have gone; left alone, it goes away and
-- nothing is sent.
--
-- The rules, each held by tests/scenarios/thankpress.lua:
--   * whether a thank is due at all is Favours.lua's, as ever (Blocked,
--     UnseenBlocked: a fight, an instance, stealth, the limits per person),
--     asked at the landing with the gap between two thanks left out, and for
--     an unseen giver with the target left out, since both are the press's to
--     read; and every one of those rules is asked again at the press;
--   * an entry of its own on the queue at TP.PRIORITY (2.5): behind a favour
--     you owe, a request, yourself and your group, ahead of passers-by and an
--     ask. Never for somebody the queue already offers something (they are
--     thanked once that is done), nor a member a group cast covers;
--   * TP.EXPIRE seconds once the prompt first shows it, TP.DEADLINE after the
--     landing, then it lapses; a fight, a loading screen or the switch going
--     off drops every one, and nothing is sent;
--   * a right-click, or Let it go in the launcher's menu, lets it go: nothing
--     sent, nobody blocked, nobody on the never-offer list, and the same
--     giver is not offered again for the per-person limit (`declinedAt`), as a
--     favour skipped is never thanked later;
--   * nothing is armed: the button holds no macro, and the press sends the
--     thanks from PostClick (ns.ThankNow, Favours.lua).
--
-- The hooks in the shared files are single lines: Favours.lua (ThankFavour and
-- ThankUnseen hand a thank to ns.ThankPark; ns.ThankNow sends one), Core.lua
-- (ns.CanCastAnything, ns.BuffInfo), Prompt/Macro.lua (Arm, ClickSummary,
-- FightMacro), Prompt/Press.lua (PreClick, PostClick, the right-click, a list
-- row, the bar macro), Prompt/Paint.lua (ReasonText, MovedOn),
-- Prompt/Button.lua (the tooltip), Options/Launcher.lua (the tooltip and the
-- menu), Commands.lua and Options/Diagnostics.lua (ns.ThankPressLines).
-- ns.BuildQueue is wrapped at the end of this file, as Resurrect.lua wraps it.

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain = ns.plain
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local TP = {}
ns.ThankPress = TP

-- After your group (Queue.lua, PRIORITY: group 2), ahead of passers-by (3).
TP.PRIORITY = 2.5
-- How long the prompt shows one, from the first time it does.
TP.EXPIRE = 20
-- How long one waits at all, from the landing.
TP.DEADLINE = 60
-- How many wait at once; the oldest goes first.
TP.MAX = 5

-- The name the queue files a thank for somebody nobody could name under.
local UNSEEN = "?thank"
-- A whisper by name and the scan's reading of one landing (Favours.lua).
local SAME_LANDING = 60
-- Favours.lua's limits per person, for a thank let go.
local PER_PERSON, PER_MEMBER = 300, 1800

-- The thanks waiting for a press, in landing order:
-- { id, seen, emote, whisper, unseen, at, shownAt, entry }.
local pending = {}
local seq = 0
-- [name], or ["?" .. spell] for one nobody could name = when it was let go.
local declinedAt = {}

local function Profile()
	return addon.db and addon.db.profile
end

-- Whether the switch is on, and something to send.
local function Live(db)
	local p = db and db.prompt
	return db ~= nil and db.enabled == true and type(p) == "table" and p.thankAsk == true
		and (p.thankEmote == true or p.thankWhisper == true)
end

local function NameOf(item)
	return item.unseen and UNSEEN or item.seen.name
end

local function DeclineKey(unseen, seen)
	return unseen and ("?" .. tostring(seen.key)) or seen.name
end

-- What a press of this one would send now, the switches read as they stand:
-- the emote, the whisper, and whether that is anything at all.
local function ItemChannels(item, p)
	if item.unseen then
		local emote = p.thankUnseen == true and p.thankEmote == true
		return emote, false, emote
	end
	-- A whisper by name goes only while Thank them even when I can't see who it was is on.
	if item.seen.byName and p.thankUnseen ~= true then return false, false, false end
	local emote = item.emote == true and p.thankEmote == true
	local whisper = item.whisper == true and p.thankWhisper == true
	return emote, whisper, emote or whisper
end

local function Find(id)
	if id == nil then return nil end
	for i, item in ipairs(pending) do
		if item.id == id then return i, item end
	end
	return nil
end

-- Off the queue, and off the panel now: the hold and the fuse let go of a
-- name blocked under the entry's key (Prompt/Hold.lua, Retired). `declined`
-- for one the player let go or let lapse.
local function Drop(i, declined)
	local item = table.remove(pending, i)
	if not item then return nil end
	ns.MarkAttempted(NameOf(item), "thank:" .. item.id, 30)
	if declined then
		local now = GetTime()
		for key, at in pairs(declinedAt) do
			if now - at >= PER_MEMBER then declinedAt[key] = nil end
		end
		declinedAt[DeclineKey(item.unseen, item.seen)] = now
		-- Every spell one unseen offer stood for, not only the newest.
		for key in pairs(item.keys or {}) do declinedAt["?" .. tostring(key)] = now end
	end
	return item
end

local function DropAll(declined)
	for i = #pending, 1, -1 do Drop(i, declined) end
end

local function RepaintNow()
	local prompt = ns.Prompt
	if prompt then ns.Guard("thank repaint", prompt.Refresh, prompt) end
end

-- A repaint next frame: a landing is noticed inside the walk of your auras,
-- which a repaint in the middle of would walk again.
local function After(seconds, fn)
	local timer = _G.C_Timer
	if type(timer) == "table" and type(timer.After) == "function" then timer.After(seconds, fn) end
end

local function Repaint()
	After(0, RepaintNow)
end

---------------------------------------------------------------------------
-- a thank parked
---------------------------------------------------------------------------

-- Favours.lua's hand-off, once its rules have said a thank is due: `emote`
-- and `whisper` as the thank would have gone, `unseen` for a landing nobody
-- could name (the emote with nobody targeted).
function ns.ThankPark(seen, emote, whisper, unseen)
	if type(seen) ~= "table" then return end
	unseen = unseen == true
	if not unseen and type(seen.name) ~= "string" then return end
	local now = GetTime()
	-- Let go a moment ago: not offered again for the limit a thank keeps.
	local at = declinedAt[DeclineKey(unseen, seen)]
	if at and now - at < (seen.inGroup and PER_MEMBER or PER_PERSON) then return end
	local found
	for i = #pending, 1, -1 do
		local item = pending[i]
		local same = item.seen.key == seen.key and now - item.at < SAME_LANDING
		if unseen then
			-- One landing the combat log named first: the whisper by name stands.
			if item.seen.byName and same then return end
			if item.unseen then found = item end
		elseif item.unseen then
			if seen.byName and same then Drop(i, false) end
		elseif item.seen.name == seen.name then
			found = item
		end
	end
	if found then
		-- Their newer landing: the same offer, for the newer buff.
		found.seen, found.emote, found.whisper, found.at, found.entry = seen, emote == true, whisper == true, now, nil
		-- Its time on the prompt starts again with it.
		if found.shownAt then
			found.shownAt = now
			After(TP.EXPIRE + 0.05, RepaintNow)
		end
		if found.keys then found.keys[seen.key] = true end
	else
		seq = seq + 1
		pending[#pending + 1] = { id = seq, seen = seen, emote = emote == true, whisper = whisper == true,
			unseen = unseen, at = now, keys = unseen and { [seen.key] = true } or nil }
		-- The oldest pushed out: declined only if the prompt ever showed it.
		while #pending > TP.MAX do Drop(1, pending[1].shownAt ~= nil) end
	end
	ns.Trail("thank", ("waiting for a press to thank (spell %s)"):format(tostring(seen.key)), seen.name)
	After(TP.DEADLINE + 0.05, RepaintNow)
	Repaint()
end

-- Whether one waits (ns.CanCastAnything: a rogue has a prompt for it).
function ns.ThankPending()
	return pending[1] ~= nil and Live(Profile())
end

---------------------------------------------------------------------------
-- the entry
---------------------------------------------------------------------------

-- The entry's buff is a table of this file's own, never a row of the sets, so
-- nothing that reads a buff's flags takes it for one of yours; its name and
-- icon are the buff they gave you, handed to ns.BuffInfo (`thankInfo`).
local function Wrap(item)
	if item.entry then return item.entry end
	local seen = item.seen
	local key = "thank:" .. item.id
	local spell = seen.key
	local spellName = type(spell) == "number" and ns.SpellNameFor(spell) or nil
	local icon = type(spell) == "number" and ns.safecall(C_Spell and C_Spell.GetSpellTexture, spell) or nil
	local buff = {
		key = key,
		thank = true,
		-- Lands on nobody but you: nothing of a buff's reach is read of it.
		alone = true,
		thankInfo = {
			key = key,
			name = type(spellName) == "string" and spellName ~= "" and spellName or tostring(spell),
			icon = icon,
			known = false,
			readable = false,
			secrecy = {},
			unresolved = {},
		},
	}
	local short = item.unseen and L["whoever buffed you"] or ns.ShortName(seen.name) or seen.name
	local entry = {
		name = NameOf(item),
		short = short,
		display = L["Thank %s"]:format(short),
		unit = not item.unseen and seen.unit or nil,
		class = not item.unseen and seen.class or nil,
		buff = buff,
		reason = "thank",
		thank = item.id,
		thankUnseen = item.unseen or nil,
		inGroup = seen.inGroup == true,
		priority = TP.PRIORITY,
		ranged = true,
		known = false,
		checked = true,
	}
	item.entry = entry
	return entry
end

-- Nothing is offered in a fight, the pull's own repaint included, nor while
-- you could press nothing at all (dead, charmed, in a vehicle, on a taxi,
-- mounted with the prompt hidden): BuildQueue's own list.
local function Held()
	if InCombatLockdown() then return true end
	local prompt = ns.Prompt
	if prompt and prompt.armedForFight == true then return true end
	local fighting = _G.UnitAffectingCombat
	if type(fighting) == "function" and plain(fighting("player")) == true then return true end
	if plain(UnitIsDeadOrGhost("player")) == true then return true end
	if plain(UnitIsCharmed and UnitIsCharmed("player")) == true then return true end
	if UnitInVehicle and plain(UnitInVehicle("player")) == true then return true end
	if UnitOnTaxi and plain(UnitOnTaxi("player")) == true then return true end
	return ns.HiddenWhileMounted() and true or false
end

-- BuildQueue's two returns with the thanks put in at their priority.
local function Offer(queue, verdicts)
	local db = Profile()
	if not Live(db) then
		DropAll(false)
		return queue, verdicts
	end
	local now, p = GetTime(), db.prompt
	for i = #pending, 1, -1 do
		local item = pending[i]
		local _, _, any = ItemChannels(item, p)
		if now - item.at >= TP.DEADLINE or (item.shownAt and now - item.shownAt >= TP.EXPIRE) then
			-- Left on the prompt is let go; one the prompt never showed (held
			-- behind a buff they are owed, say) holds their next one back no
			-- more than an automatic thank skipped would.
			Drop(i, item.shownAt ~= nil)
		elseif not any then
			Drop(i, false)
		end
	end
	if pending[1] == nil or type(queue) ~= "table" or Held() then return queue, verdicts end

	-- Somebody with something else on the queue is thanked once that is done;
	-- an ask of them gives way to the thank, and comes back at the next scan.
	local taken = {}
	for _, entry in ipairs(queue) do
		if entry.name and not entry.ask then taken[entry.name] = true end
		local group = entry.groupCast
		if group and type(group.members) == "table" then
			for _, member in ipairs(group.members) do taken[member] = true end
		end
	end
	-- Favours.lua's own hold (stealth, an encounter, chat held back): kept,
	-- not offered, as a press could send nothing. Asked of one, since every
	-- reason but a battleground's team is the player's own.
	local thankNow = ns.ThankNow
	if thankNow and thankNow.Held(pending[1].seen) then return queue, verdicts end
	for _, item in ipairs(pending) do
		local entry = Wrap(item)
		if not taken[entry.name] then
			taken[entry.name] = true
			for i = #queue, 1, -1 do
				if queue[i].ask and queue[i].name == entry.name then table.remove(queue, i) end
			end
			local at = #queue + 1
			for i, other in ipairs(queue) do
				if type(other.priority) == "number" and other.priority > TP.PRIORITY then
					at = i
					break
				end
			end
			table.insert(queue, at, entry)
			if type(verdicts) ~= "table" then verdicts = {} end
			verdicts[entry.name] = nil
		end
	end
	return queue, verdicts
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

local CLEARED = { "type1", "macrotext1", "spell1", "unit1", "type", "macrotext", "spell", "unit",
	"type2", "type3", "type4", "type5" }

-- Arm's hook (Prompt/Macro.lua): nothing on the button. The press is
-- PostClick's (TP.Pressed). The prompt's first showing starts its clock; a
-- list row's arming, the launcher's tooltip and a snoozed prompt start none.
function ns.ThankArm(R, S, entry)
	local applied = "thank\1" .. tostring(entry.thank)
	if applied == S.appliedKey then return end
	for _, attribute in ipairs(CLEARED) do R.button:SetAttribute(attribute, nil) end
	S.armed = nil
	S.phraseKey, S.phraseText, S.phraseArmed, S.phraseSource = nil, nil, nil, nil
	S.barText, S.barSpoke, S.barSource = nil, nil, nil
	if not S.isRow then
		local _, item = Find(entry.thank)
		if item and not item.shownAt then
			item.shownAt = GetTime()
			After(TP.EXPIRE + 0.05, RepaintNow)
		end
		ns.lastMacro = "[thank, not armed]"
		ns.SyncMacroSlot(nil)
	end
	S.appliedKey = applied
end

-- OnPostClick's hook (Prompt/Press.lua): a left press on a thank, the prompt's
-- or a list row's. Off the queue first, so no second press can send it again,
-- then every rule read again and the thanks sent (Favours.lua, ns.ThankNow).
function TP.Pressed(S)
	local entry = S.current
	local db = Profile()
	local i, item = Find(entry and entry.thank)
	if not (item and db) then
		if db and db.verbose then addon:Print(L["that thank-you has lapsed."]) end
		RepaintNow()
		return
	end
	local emote, whisper, any = ItemChannels(item, db.prompt)
	Drop(i, false)
	if not (Live(db) and any) then
		RepaintNow()
		return
	end
	local why = ns.ThankNow.Press(item.seen, emote, whisper, item.unseen)
	if why and item.unseen and why == L["you have somebody targeted"] then
		-- Kept: the reason line says to clear the target, and a press then thanks.
		ns.MarkAttempted(UNSEEN, "thank:" .. item.id, 0)
		table.insert(pending, math.min(i, #pending + 1), item)
		addon:Print(L["not thanked: %s."]:format(why))
	elseif why then
		addon:Print(L["not thanked: %s."]:format(why == L["no unit for them"] and L["they are out of sight now"] or why))
	else
		ns.Trail("thank", "thanked at a press, from " .. (S.isRow and "the list" or "the prompt"),
			not item.unseen and item.seen.name or nil)
	end
	if not S.isRow then ns.Prompt:StopAttention() end
	RepaintNow()
end

-- A right-click on one, or Let it go in the launcher's menu: nothing sent.
function TP.DismissEntry(entry, fromRow)
	local i = Find(entry and entry.thank)
	if i then Drop(i, true) end
	local db = Profile()
	if db and db.verbose then
		addon:Print(L["not thanking |cffffffff%s|r this time."]:format(tostring(entry and entry.short or "?")))
	end
	if not fromRow and ns.Prompt then ns.Prompt:StopAttention() end
	RepaintNow()
end

function TP.Dismiss(S)
	return TP.DismissEntry(S.current, S.isRow)
end

---------------------------------------------------------------------------
-- what the prompt says of it
---------------------------------------------------------------------------

-- The second line of the panel and of a list row.
function TP.Reason(entry)
	if entry.thankUnseen and plain(UnitExists("target")) == true then return L["clear your target to thank them"] end
	return L["for %s -- they buffed you"]:format(ns.BuffName(entry.buff))
end

-- The tooltip's line about the person.
function TP.TooltipLine()
	return L["Buffed you a moment ago. A press thanks them as you have set it up; a right-click lets it go."]
end

-- What a press sends, as the press would read the switches now.
function TP.Summary(entry)
	local out = {}
	local db = Profile()
	local _, item = Find(entry and entry.thank)
	if not (db and item) then
		out[1] = L["that thank-you has lapsed."]
		return out
	end
	local p = db.prompt
	local emote, whisper = ItemChannels(item, p)
	local who = entry.short or entry.name or "?"
	if emote then
		local first = ns.THANK_EMOTE_SET[p.thankEmoteToken] and p.thankEmoteToken or "THANK"
		local more = false
		if type(p.thankEmoteMore) == "table" then
			for token, on in pairs(p.thankEmoteMore) do
				if on == true and token ~= first and ns.THANK_EMOTE_SET[token] then
					more = true
					break
				end
			end
		end
		if item.unseen then
			out[#out + 1] = more and L["Emote: one of your thank emotes, with nobody targeted"]
				or L["Emote: |cffffffff%s|r with nobody targeted"]:format("/" .. first:lower())
		else
			out[#out + 1] = more and L["Emote: one of your thank emotes, at |cffffffff%s|r"]:format(who)
				or L["Emote: |cffffffff%s|r at |cffffffff%s|r"]:format("/" .. first:lower(), who)
		end
	end
	if whisper then out[#out + 1] = L["Whispers |cffffffff%s|r a thank-you"]:format(who) end
	out[#out + 1] = L["Casts nothing and leaves your target alone."]
	out[#out + 1] = L["Right-click: let it go, nothing is sent."]
	return out
end

---------------------------------------------------------------------------
-- /manners debug and the full check-up
---------------------------------------------------------------------------

function ns.ThankPressLines(now)
	local out = {}
	local db = Profile()
	if not (db and type(db.prompt) == "table" and db.prompt.thankAsk == true) then return out end
	now = now or GetTime()
	out[1] = L["ask me before thanking: |cff00ff00on|r"]
	for _, item in ipairs(pending) do
		local left = TP.DEADLINE - (now - item.at)
		if item.shownAt then left = math.min(left, TP.EXPIRE - (now - item.shownAt)) end
		out[#out + 1] = L["waiting for your press to thank: |cffffffff%s|r, %ds left"]
			:format(item.unseen and L["whoever buffed you"] or tostring(item.seen.name), math.max(0, math.floor(left)))
	end
	return out
end

---------------------------------------------------------------------------
-- a fight, a loading screen
---------------------------------------------------------------------------

do
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function()
		if pending[1] == nil then return end
		ns.Guard("thank press reset", DropAll, false)
	end)
end

-- The queue. With nothing waiting a scan pays one comparison here.
do
	local Build = ns.BuildQueue
	function ns.BuildQueue(watch)
		local queue, verdicts = Build(watch)
		if pending[1] == nil then return queue, verdicts end
		return Offer(queue, verdicts)
	end
end
