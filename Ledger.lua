-- Manners -- the favour ledger.
--
-- A record of what the addon has done for you: who buffed you, with what and
-- when, whether you returned it and with what, and who you buffed without being
-- asked. The recent entries are listed in a small window (/manners ledger), under
-- the lifetime counts, which the minimap tooltip and the General tab repeat.
--
-- It is a record and never a decision. Core.lua tells it what happened at the
-- four moments a favour changes hands -- noticed, repaid, refused after all, and
-- let go, bar one way of letting go it listens for itself (see LetGo) -- and
-- nothing anywhere reads a ledger entry to decide what to offer
-- or whom to cast at. That is on purpose: the debt table in Core.lua is what the
-- prompt works from, and a second opinion about who is owed would be exactly the
-- kind of drift the rest of this addon has spent rounds removing. So everything
-- here is allowed to be wrong in one way only -- by missing something -- and a
-- ledger that throws takes nothing with it, because Core calls it through Guard.
--
-- The window is plain UI with no secure frame anywhere in it, so unlike the
-- prompt it can be opened, scrolled, cleared and dragged in a fight.

local ADDON, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

local Ledger = {}
ns.Ledger = Ledger

local GetTime = _G.GetTime
-- Read once at load, like Core's own copy. Asked directly rather than through
-- Core's helper because a name is kept for good here: that helper answers
-- whether a value may be looked at now, and this is the same question asked
-- about the one thing this file writes to disk.
local issecretvalue = _G.issecretvalue

---------------------------------------------------------------------------
-- text
--
-- Every sentence a player reads, in one place and each one whole, because a
-- sentence assembled from pieces cannot be translated. Format strings carry the
-- numbers and names; each is looked up in L once, at load, which is after the
-- locale files have filled it.
---------------------------------------------------------------------------

local TEXT = {
	TITLE = L["Favour ledger"],
	-- A glyph drawn as the close button, not a word, so it is the same in
	-- every language and there is nothing to hand a translator.
	CLOSE = "x",
	CLOSE_TIP = L["Close (Escape works too)"],

	-- The headline over the list, and the line the minimap tooltip and the
	-- options page repeat. "Today" is the calendar day on this computer's
	-- clock. It counts only the favours something you cast could have
	-- returned: a warrior's shout to a mage is listed, but scoring it as a
	-- favour not returned would be a failure the player can do nothing about.
	--
	-- "Recorded" rather than "nobody buffed you": the ledger hears of nothing
	-- while the addon is off or has nothing to cast, and after Clear, so all
	-- it can say is what it has.
	TODAY_NONE = L["No favours recorded today."],
	TODAY_ONLY_USELESS = L["Nothing you cast could return today's favours."],
	TODAY_ONE = L["Returned %d of 1 favour today."],
	TODAY_MANY = L["Returned %d of %d favours today."],
	OWED_ONE = L["1 favour still owed."],
	OWED_MANY = L["%d favours still owed."],
	-- Casts, not people: topping up the same five players three times is
	-- fifteen buffs and still five players.
	GAVE_ONE = L["You gave 1 buff unprompted today."],
	GAVE_MANY = L["You gave %d buffs unprompted today."],
	LIFETIME = L["All time -- received: %d, returned: %d, given to your group: %d, to strangers: %d"],

	-- The same four numbers as tiles across the window, each with its label
	-- underneath, and the caption over them.
	ALL_TIME = L["All time"],
	STAT_RECEIVED = L["received"],
	STAT_RETURNED = L["returned"],
	STAT_GROUP = L["to your group"],
	STAT_STRANGERS = L["to strangers"],
	-- Where the rows on screen sit in the list: "1-8 of 42".
	SHOWING = L["%d-%d of %d"],

	TAB_ALL = L["Everything"],
	TAB_FAVOURS = L["Favours"],
	TAB_GIVEN = L["Buffs you gave"],

	EMPTY_ALL = L["Nothing recorded. When somebody buffs you it is listed here, and so is what you give back and who you buff unprompted."],
	EMPTY_FAVOURS = L["No favours recorded. When somebody buffs you, they are listed here."],
	EMPTY_GIVEN = L["No buffs given unprompted. When the prompt buffs somebody who did not buff you first, it is listed here."],
	-- In place of the lines above while nothing new can arrive, because "when
	-- somebody buffs you it is listed here" is then a promise the addon is not
	-- keeping. The owed toggle stops favours only; buffs given still arrive.
	EMPTY_OFF = L["Nothing is recorded while Manners is switched off."],
	EMPTY_NOTHING = L["Nothing is recorded while the prompt has nothing to cast on this character."],
	EMPTY_OWED_OFF = L["Favours are not recorded while \"People who buffed me\" is off, on the Who to buff tab."],

	CLEAR = L["Clear"],
	CLEAR_ARMED = L["Click again to clear"],
	CLEAR_TIP = L["Empties the list, and today's count with it. Favours you still owe stay, and the all-time totals are kept."],

	-- The badge at the front of a row's second line, and what follows it. A
	-- row reads "badge  detail": the badge is a coloured status word, then two
	-- spaces, then one of the details below, so each detail finishes the
	-- badge's phrase without repeating it. The badges are separate keys because
	-- a returned favour with no spell to name shows its badge alone, and
	-- because the badge takes its own colour; a detail that needs its words in
	-- another order has them all in its own key.
	--
	-- Badges: a favour owed to the row's player; one returned; one let go
	-- unreturned; and a buff you gave them unprompted, when nobody owed it.
	STATE_OWED = L["Still owed"],
	STATE_RETURNED = L["Returned"],
	STATE_LETGO = L["Let go"],
	STATE_GAVE = L["Gave"],
	-- After "Returned": %s is the spell you returned the favour with.
	RETURNED_WITH = L["with %s"],
	-- After "Let go": why it was let go.
	LETGO_EXPIRED = L["the time to return it ran out"],
	LETGO_USELESS = L["nothing you cast is any use to them"],
	LETGO_NOTKEPT = L["forgotten at a logout or reload"],
	-- A favour the player let go on purpose, by putting its giver on the
	-- never-offer list.
	LETGO_NEVER = L["you put them on your never-offer list"],
	-- After "Gave": %s is the spell you gave the row's player.
	GAVE_GROUP = L["%s, in your group"],
	GAVE_STRANGER = L["%s, to a stranger"],
	-- In place of a spell name the client could not give.
	UNKNOWN_SPELL = L["a buff"],

	-- The row tooltip, which is where the whole story goes.
	TIP_BUFFED = L["Buffed you with %s, %s."],
	TIP_TIMES = L["They buffed you %d times; one buff back repays all of it."],
	TIP_OWED = L["Still owed. The prompt offers them until you return it or the time runs out."],
	-- A warrior's shout and the like reach the caster's party and nobody else,
	-- so a favour from outside it waits for them to be in it. Said so it is
	-- true whether or not they are in it now.
	TIP_OWED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it."],
	TIP_OWED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it."],
	TIP_RETURNED = L["You returned it %s later."],
	TIP_RETURNED_WITH = L["You returned it %s later, with %s."],
	TIP_LETGO_EXPIRED = L["Let go: the time to return it ran out before you did."],
	TIP_LETGO_USELESS = L["Let go: nothing you can cast is any use to them."],
	-- Quotes the setting by the name it has on the When tab, which a scenario
	-- holds it to.
	TIP_LETGO_NOTKEPT = L["Let go: \"Remember them across a reload\" (When tab, under Timing) is off, so it was forgotten when you logged out or reloaded."],
	TIP_LETGO_NEVER = L["Let go: you put them on your never-offer list."],
	-- In place of TIP_OWED while the prompt cannot offer them, which is the
	-- rule Quiet() below keeps for the empty list: the window never promises
	-- what cannot come. The toggle is quoted by the name it has on the Who to
	-- buff tab, and %s is the time the snooze ends, on the player's clock.
	TIP_OWED_OFF = L["Still owed, but Manners is switched off, so the prompt will not offer them."],
	TIP_OWED_SOURCE_OFF = L["Still owed, but the prompt is not offering favours while \"People who buffed me\" is off."],
	TIP_OWED_NOTHING = L["Still owed, but there is nothing on this character the prompt can cast."],
	TIP_OWED_SNOOZED = L["Still owed. The prompt is snoozed until %s, so it offers them only if the snooze ends before the time to return it runs out."],
	TIP_OWED_MOUNTED = L["Still owed. The prompt stays away while you are mounted, and offers them once you get off, until the time to return it runs out."],
	-- The same two for a favour only your party can return, as TIP_OWED_PARTY
	-- and TIP_OWED_SUBGROUP say it: the snooze or the ride ending is not
	-- enough while they are outside your party.
	TIP_OWED_SNOOZED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it, and it is snoozed until %s: they are offered only if the snooze ends before the time to return it runs out."],
	TIP_OWED_SNOOZED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it, and it is snoozed until %s: they are offered only if the snooze ends before the time to return it runs out."],
	TIP_OWED_MOUNTED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it, and it stays away while you are mounted: they are offered once you get off, if they are in it, until the time to return it runs out."],
	TIP_OWED_MOUNTED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it, and it stays away while you are mounted: they are offered once you get off, if they are in it, until the time to return it runs out."],
	TIP_GAVE = L["You buffed them with %s, %s."],
	TIP_GAVE_GROUP = L["They were in your group and had not buffed you."],
	TIP_GAVE_STRANGER = L["They were not in your group and had not buffed you."],

	JUST_NOW = L["just now"],
	MINUTES_AGO = L["%d min ago"],
	HOURS_AGO = L["%d hr ago"],
	DAY_AGO = L["a day ago"],
	DAYS_AGO = L["%d days ago"],
	SECONDS = L["%d sec"],
	MINUTES = L["%d min"],
	HOURS = L["%d hr"],

	OPTIONS_EMPTY = L["Nothing has been recorded on this character yet."],
}
Ledger.TEXT = TEXT

---------------------------------------------------------------------------
-- bounds
---------------------------------------------------------------------------

-- The list kept on disk. Two hundred rows is weeks of ordinary play and a few
-- kilobytes in the saved file; the lifetime counts are kept separately and are
-- never trimmed.
local MAX_ENTRIES = 200
-- Of which buffs given unprompted may take at most half. A mage walking through
-- a city buffs a stranger every few seconds, and without a share of their own
-- those would push every favour off the end of the list inside an hour -- the
-- favours being the reason the list exists.
local MAX_GIVEN = 100
-- The spells one favour remembers. A priest lands three buffs at once, and that
-- is one favour with three names on it rather than three rows.
local MAX_SPELLS = 3
-- A second buff from the same person inside this many seconds is the same
-- favour. Wider than one landing needs, narrower than any recast.
local FOLD_SECONDS = 10
-- How long a settle is kept for a refusal to undo it. Core keeps its own record
-- for its SETTLE_SECONDS and only ever calls back inside that; this is a
-- generous bound on a list that would otherwise grow for the session.
local UNDO_SECONDS = 30

local STATES = { owed = true, returned = true, letgo = true }
-- Why a favour was let go: its time ran out, nothing you cast is any use to
-- them, it was forgotten at a reload, or you put them on the never-offer list.
local WHY = { expired = true, useless = true, notkept = true, never = true }
local FILTERS = { all = true, favours = true, given = true }
local TOTALS = { "received", "returned", "letGo", "group", "strangers" }
local POINTS = {
	CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

---------------------------------------------------------------------------
-- reading values the client hands over
---------------------------------------------------------------------------

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A name that may be kept, or nil. The same rules the debt table's names pass,
-- restated because this is the other place a name goes to disk, and because the
-- window prints it: a secret, anything too long to be a character's name, and
-- anything carrying a chat escape or macro punctuation are all refused. A name
-- never comes back out of here as something other than the plain string it
-- went in as.
local function CleanName(name)
	if Secret(name) or type(name) ~= "string" then return nil end
	if name == "" or #name > 48 then return nil end
	if name:find("[%[%]\n\r;|]") then return nil end
	return name
end

-- The client's class token, MAGE or PRIEST: capitals and nothing else, so it
-- can index the colour table and can never carry anything into the text.
local function CleanClass(class)
	if Secret(class) or type(class) ~= "string" or #class > 20 then return nil end
	if not class:find("^%u+$") then return nil end
	return class
end

local function CleanSpell(id)
	if Secret(id) or type(id) ~= "number" then return nil end
	if id <= 0 or id ~= math.floor(id) or id > 10000000 then return nil end
	return id
end

local function CleanTime(t)
	if Secret(t) or type(t) ~= "number" then return nil end
	if t ~= t or t <= 0 or t == math.huge then return nil end
	return t
end

local function Count(v)
	if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return 0 end
	return math.floor(v)
end

-- The wall clock. Everything stored is on it, for the reason Core's debts are:
-- GetTime() starts again near zero after a reboot and means nothing on disk.
local function Wall()
	local ok, t = pcall(_G.time)
	if not ok then return nil end
	return CleanTime(t)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if not ok or Secret(value) then return nil end
	return value
end

local function SpellName(id)
	if not id then return nil end
	local name = Call(C_Spell and C_Spell.GetSpellName, id) or Call(_G.GetSpellInfo, id)
	return type(name) == "string" and name or nil
end

-- The question mark every spell book falls back to.
local QUESTION_MARK = 134400

local function SpellIcon(id)
	if not id then return QUESTION_MARK end
	return Call(C_Spell and C_Spell.GetSpellTexture, id) or Call(_G.GetSpellTexture, id)
		or QUESTION_MARK
end

local function Coloured(name, class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and type(c.colorStr) == "string" then
		return ("|c%s%s|r"):format(c.colorStr, name)
	end
	return name
end

---------------------------------------------------------------------------
-- time as a player reads it
---------------------------------------------------------------------------

function Ledger.Ago(seconds)
	seconds = math.max(0, seconds or 0)
	if seconds < 45 then return TEXT.JUST_NOW end
	if seconds < 3600 then return TEXT.MINUTES_AGO:format(math.max(1, math.floor(seconds / 60 + 0.5))) end
	if seconds < 86400 then return TEXT.HOURS_AGO:format(math.max(1, math.floor(seconds / 3600 + 0.5))) end
	local days = math.floor(seconds / 86400)
	if days == 1 then return TEXT.DAY_AGO end
	return TEXT.DAYS_AGO:format(days)
end

local function Duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds < 60 then return TEXT.SECONDS:format(seconds) end
	if seconds < 3600 then return TEXT.MINUTES:format(math.floor(seconds / 60 + 0.5)) end
	return TEXT.HOURS:format(math.floor(seconds / 3600 + 0.5))
end

-- Local midnight, on this computer's clock. date("*t") is the only thing that
-- knows the time zone; where it will not answer with a table -- nothing this
-- addon runs on, but the fallback has to be something -- "today" is the last
-- day's worth of seconds rather than nothing at all.
local function StartOfToday(now)
	local ok, t = pcall(_G.date, "*t", now)
	if ok and type(t) == "table" and type(t.hour) == "number"
		and type(t.min) == "number" and type(t.sec) == "number" then
		return now - ((t.hour * 60 + t.min) * 60 + t.sec)
	end
	return now - 86400
end

---------------------------------------------------------------------------
-- the store
--
-- db.char, like the debts: a favour is done to a character, and profiles are
-- shared between characters. AceDB keeps it inside the one saved file.
--
--   ledger.entries  oldest first; each one either
--     { kind = "received", name, class, spells = { id, ... }, at, times,
--       state = owed | returned | letgo, why, doneAt, gave, partyOnly }
--     { kind = "given", name, class, spell, at, to = group | stranger }
--   ledger.totals   lifetime counts, never trimmed and kept by Clear
--   ledger.today    { day = local midnight, given = n }: today's buffs given,
--                   which the trim cannot touch and Clear resets
--   ledger.filter   the window's tab
--   ledger.window   where the window was dragged to
---------------------------------------------------------------------------

local store

local function CleanEntry(e)
	if type(e) ~= "table" then return nil end
	local name, at = CleanName(e.name), CleanTime(e.at)
	if not name or not at then return nil end
	local class = CleanClass(e.class)

	if e.kind == "given" then
		return { kind = "given", name = name, class = class, at = at,
			spell = CleanSpell(e.spell), to = e.to == "group" and "group" or "stranger" }
	elseif e.kind == "received" then
		local spells = {}
		if type(e.spells) == "table" then
			for i = 1, MAX_SPELLS do
				local id = CleanSpell(e.spells[i])
				if id then spells[#spells + 1] = id end
			end
		end
		-- A state nobody wrote is a favour whose outcome is unknown, and the
		-- one outcome that cannot be wrong about it is that it is over. Calling
		-- it owed would put a row on screen promising the prompt is offering
		-- somebody it has never heard of.
		local state = STATES[e.state] and e.state or "letgo"
		local out = { kind = "received", name = name, class = class, at = at,
			spells = spells, times = math.max(1, Count(e.times)), state = state }
		if state == "owed" and e.partyOnly == true then out.partyOnly = true end
		if state ~= "owed" then out.doneAt = CleanTime(e.doneAt) end
		if state == "returned" then out.gave = CleanSpell(e.gave) end
		if state == "letgo" then out.why = WHY[e.why] and e.why or nil end
		return out
	end
	return nil
end

-- Oldest out first, but never a favour still owed: its settle is on its way,
-- and a settle that finds no row makes one and counts the favour a second time.
-- Those are bounded anyway, by how many people can owe you at once.
local function Trim(s)
	local entries = s.entries
	local given = 0
	for i = 1, #entries do
		if entries[i].kind == "given" then given = given + 1 end
	end
	local i = 1
	while given > MAX_GIVEN and i <= #entries do
		if entries[i].kind == "given" then
			table.remove(entries, i)
			given = given - 1
		else
			i = i + 1
		end
	end
	i = 1
	while #entries > MAX_ENTRIES and i <= #entries do
		if entries[i].state == "owed" then
			i = i + 1
		else
			table.remove(entries, i)
		end
	end
end

-- Whatever is on disk, made into something every reader below can trust: a
-- profile from before the ledger existed has nothing here, and a file somebody
-- edited, or a crash wrote half of, can have anything at all. Rebuilt rather
-- than patched, so no key this file does not know survives into the next save.
local function Repair(char)
	local s = char.ledger
	if type(s) ~= "table" then
		s = {}
		char.ledger = s
	end

	local kept = {}
	if type(s.entries) == "table" then
		for i = 1, #s.entries do
			local e = CleanEntry(s.entries[i])
			if e then kept[#kept + 1] = e end
		end
	end
	-- Oldest first is what everything below assumes, and a damaged file need
	-- not be in any order. The index breaks ties so equal times keep theirs.
	for i, e in ipairs(kept) do e.order = i end
	table.sort(kept, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.order < b.order
	end)
	for _, e in ipairs(kept) do e.order = nil end
	s.entries = kept

	-- The counts never read lower than the list in front of them. A file that
	-- lost its totals but kept its rows would otherwise say "all time: 0" over
	-- a list of forty favours.
	local seen = { received = 0, returned = 0, letGo = 0, group = 0, strangers = 0 }
	for _, e in ipairs(kept) do
		if e.kind == "received" then
			seen.received = seen.received + 1
			if e.state == "returned" then seen.returned = seen.returned + 1 end
			if e.state == "letgo" then seen.letGo = seen.letGo + 1 end
		elseif e.to == "group" then
			seen.group = seen.group + 1
		else
			seen.strangers = seen.strangers + 1
		end
	end
	local old = type(s.totals) == "table" and s.totals or {}
	local totals = {}
	for _, key in ipairs(TOTALS) do
		totals[key] = math.max(Count(old[key]), seen[key])
	end
	s.totals = totals

	s.filter = FILTERS[s.filter] and s.filter or "all"

	-- Today's count of buffs given, kept apart from the list: see Summary.
	-- Kept only whole, a day that is a number and a count that is one.
	local today = s.today
	if type(today) == "table" and CleanTime(today.day) and type(today.given) == "number"
		and today.given >= 0 and today.given == math.floor(today.given) and today.given ~= math.huge then
		s.today = { day = today.day, given = today.given }
	else
		s.today = nil
	end

	local w = s.window
	if type(w) == "table" and POINTS[w.point] and POINTS[w.relPoint]
		and type(w.x) == "number" and w.x == w.x and math.abs(w.x) < 10000
		and type(w.y) == "number" and w.y == w.y and math.abs(w.y) < 10000 then
		s.window = { point = w.point, relPoint = w.relPoint, x = w.x, y = w.y }
	else
		s.window = nil
	end

	Trim(s)
	store = s
	return s
end

local function Store()
	local char = ns.db and ns.db.char
	if type(char) ~= "table" then return nil end
	if store == nil or char.ledger ~= store then return Repair(char) end
	return store
end

local function Bump(s, key, by)
	s.totals[key] = math.max(0, (s.totals[key] or 0) + (by or 1))
end

local function Append(s, e)
	s.entries[#s.entries + 1] = e
	Trim(s)
end

local function Holds(s, e)
	for i = #s.entries, 1, -1 do
		if s.entries[i] == e then return true end
	end
	return false
end

local function Remove(s, e)
	for i = #s.entries, 1, -1 do
		if s.entries[i] == e then
			table.remove(s.entries, i)
			return true
		end
	end
	return false
end

-- The favour this person is still owed for, newest first. There is at most one
-- in practice: a second buff from somebody already owed is folded into it,
-- because the debt table keeps one debt per person and one buff back repays it.
local function FindOpen(s, name)
	for i = #s.entries, 1, -1 do
		local e = s.entries[i]
		if e.kind == "received" and e.state == "owed" and e.name == name then return e end
	end
	return nil
end

local function AddSpell(e, id)
	if not id then return end
	for _, have in ipairs(e.spells) do
		if have == id then return end
	end
	if #e.spells < MAX_SPELLS then e.spells[#e.spells + 1] = id end
end

---------------------------------------------------------------------------
-- repainting
---------------------------------------------------------------------------

local Render -- the window's, defined with it below

local function Changed()
	if Render then Render() end
	-- The General tab prints the same numbers, and AceConfig only asks for
	-- them while it is drawing. Only while that tab is the one on screen: a
	-- repaint rebuilds the whole page, and one on every favour in a busy city
	-- redrew the dropdowns and edit boxes of the Prompt tab under the player
	-- tuning them, to refresh a line they could not see. A tab nobody can name
	-- -- a library without the status table -- is repainted as it always was.
	if ns.OptionsOpen and ns.OptionsOpen() and ns.RefreshOptionsDisplay then
		local tab = ns.OptionsTab and ns.OptionsTab()
		if tab == nil or tab == "general" then
			ns.Guard("options repaint", ns.RefreshOptionsDisplay)
		end
	end
end

---------------------------------------------------------------------------
-- what Core tells it
---------------------------------------------------------------------------

-- At login, after Core has put back the debts it kept. A favour the list still
-- has as owed, with no debt behind it any more, ran out while you were away --
-- or was never kept, when the setting to keep debts is off -- and saying it is
-- still owed would be a row contradicting the prompt.
function Ledger.Load()
	local s = Store()
	local now = Wall()
	if not s or not now then return end
	local owed = ns.owed or {}
	local profile = ns.db and ns.db.profile
	local timing = profile and profile.timing
	local window = timing and type(timing.reciprocateWindow) == "number"
		and timing.reciprocateWindow or 120
	local notKept = timing and timing.keepDebts == false
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" and not owed[e.name] then
			e.state = "letgo"
			e.why = notKept and "notkept" or "expired"
			e.doneAt = math.min(now, e.at + window)
			Bump(s, "letGo")
		end
	end
	Changed()
end

-- Somebody buffed you. `seen` is the record NoteFavour files: name, class and
-- the spell id under `key`. `useless` is the favour NoteFavour turns away
-- because nothing this character casts is any use to them -- a favour all the
-- same, and let go in the moment it arrived. `partyOnly` is a favour only a
-- buff that reaches your own party could return, so the prompt offers them only
-- while they are in it; the row's tooltip says so rather than promising an
-- offer that is waiting on them.
function Ledger.Received(seen, useless, partyOnly)
	local s, now = Store(), Wall()
	if not s or not now or type(seen) ~= "table" then return end
	local name = CleanName(seen.name)
	if not name then return end
	local spell = CleanSpell(seen.key)

	-- One favour per person while it is open, however many buffs it arrives
	-- as. A useless one folds only into another useless one from the same
	-- landing: it has no debt to be part of.
	local into
	if useless then
		local last = s.entries[#s.entries]
		if last and last.kind == "received" and last.name == name and last.why == "useless"
			and now - last.at <= FOLD_SECONDS then
			into = last
		end
	else
		into = FindOpen(s, name)
	end
	-- The latest word on it wins: what reaches somebody is a question about
	-- their class and yours, and the newest buff was read with the most to go
	-- on.
	partyOnly = (not useless and partyOnly == true) or nil
	if into then
		into.times = into.times + 1
		AddSpell(into, spell)
		into.class = into.class or CleanClass(seen.class)
		if not useless then into.partyOnly = partyOnly end
	else
		local e = { kind = "received", name = name, class = CleanClass(seen.class),
			spells = {}, at = now, times = 1, state = "owed", partyOnly = partyOnly }
		AddSpell(e, spell)
		if useless then
			e.state, e.why, e.doneAt = "letgo", "useless", now
			Bump(s, "letGo")
		end
		Append(s, e)
		Bump(s, "received")
	end
	Changed()
end

-- The spell that went out: the id the game reported where it would say, and
-- otherwise the rank this character knows of the buff that was armed.
local function GaveSpell(pending, spellId)
	local id = CleanSpell(spellId)
	if id then return id end
	local key = type(pending) == "table" and pending.buffKey
	local class = ns.caps and ns.caps.class
	local buff = key and ns.FindBuff and ns.FindBuff(class, key)
	if not buff then return nil end
	local info = ns.BuffInfo and ns.BuffInfo(buff)
	return CleanSpell(info and info.topRank) or CleanSpell(buff.ranks and buff.ranks[1])
end

-- Settles kept for a refusal to take back. Session only: a refusal arrives a
-- moment after its settle or not at all.
local recent = {}

-- A press went out and Core settled it. `wasOwed` is the debt that stood before
-- the settle cleared it, nil for somebody who was simply missing the buff.
-- Stamped with GetTime(), which is the stamp Core's own record carries, so the
-- refusal can name this settle and no other.
function Ledger.Settled(name, wasOwed, pending, spellId)
	local s, now = Store(), Wall()
	name = CleanName(name)
	if not s or not now or not name then return end
	local clock = GetTime()
	for i = #recent, 1, -1 do
		if clock - recent[i].clock > UNDO_SECONDS then table.remove(recent, i) end
	end

	local gave = GaveSpell(pending, spellId)
	local undo = { name = name, clock = clock }
	if wasOwed then
		local e = FindOpen(s, name)
		if not e then
			-- A debt the ledger never saw: kept from a session before the
			-- ledger existed. It is a favour received all the same, and when it
			-- was done is on the debt.
			local at = now
			if type(wasOwed) == "table" and type(wasOwed.at) == "number" then
				at = now - math.max(0, clock - wasOwed.at)
			end
			e = { kind = "received", name = name, spells = {}, at = at, times = 1, state = "owed",
				class = CleanClass(type(wasOwed) == "table" and wasOwed.class or nil) }
			Append(s, e)
			Bump(s, "received")
			undo.created = true
		end
		e.state, e.doneAt, e.gave = "returned", now, gave
		Bump(s, "returned")
		undo.entry = e
	else
		local to = type(pending) == "table" and pending.inGroup == true and "group" or "stranger"
		local e = { kind = "given", name = name, at = now, spell = gave, to = to,
			class = CleanClass(type(pending) == "table" and pending.class or nil) }
		Append(s, e)
		Bump(s, to == "group" and "group" or "strangers")
		-- Counted for today apart from the list, which keeps only MAX_GIVEN of
		-- these: counted off the list, a mage in a city read "You gave 100
		-- buffs unprompted today" from the hundredth one until midnight.
		local day = StartOfToday(now)
		if not (s.today and s.today.day == day) then s.today = { day = day, given = 0 } end
		s.today.given = s.today.given + 1
		undo.entry, undo.to = e, to
	end
	recent[#recent + 1] = undo
	Changed()
end

-- The server refused, after the fact, the cast a settle above was about. Core
-- has put the debt back; this puts the row back the way it was. `clock` is the
-- stamp on Core's record of the settle, which is the stamp on this one.
function Ledger.Refused(name, clock)
	local s = Store()
	if not s then return end
	local undo
	for i = #recent, 1, -1 do
		if recent[i].name == name and recent[i].clock == clock then
			undo = table.remove(recent, i)
			break
		end
	end
	if not undo then return end
	-- The row the settle wrote may be gone by now: Clear takes every row but
	-- the favours still owed, and it can be pressed in the second between a
	-- settle and its refusal. The counts are taken back all the same, since
	-- Clear keeps those, and a favour Core has just put back gets its owed row
	-- back with it -- left out, the next return found no row, made one, and
	-- counted the one favour a second time.
	local e = undo.entry
	if undo.to then
		Remove(s, e)
		Bump(s, undo.to == "group" and "group" or "strangers", -1)
		-- Today's count too, while today is still the day it was counted on:
		-- after midnight, or after Clear, the gift is not in it.
		if s.today and s.today.day == StartOfToday(e.at) then
			s.today.given = math.max(0, s.today.given - 1)
		end
	else
		Bump(s, "returned", -1)
		if undo.created then
			Remove(s, e)
			Bump(s, "received", -1)
		else
			-- Somebody repaid and then buffing you again before the refusal
			-- arrived already has an owed row for the new buff. Reopening this
			-- one beside it put two rows on screen for the one debt Core keeps,
			-- and only one of them would ever be closed. So the two are folded
			-- into one favour, counted once, as a second buff from somebody
			-- already owed always is.
			local open = FindOpen(s, e.name)
			if open and open ~= e then
				open.times = open.times + e.times
				for _, id in ipairs(e.spells) do AddSpell(open, id) end
				open.at = math.min(open.at, e.at)
				open.class = open.class or e.class
				Remove(s, e)
				Bump(s, "received", -1)
			else
				e.state, e.doneAt, e.gave = "owed", nil, nil
				if not Holds(s, e) then Append(s, e) end
			end
		end
	end
	Changed()
end

-- The debt was let go before it was returned. `why` is one of WHY: "never" for
-- a favour the player let go by putting its giver on the never-offer list,
-- which is on purpose and must not read as time running out. Anything else,
-- nothing included, is the sweep's case -- the time ran out -- because that is
-- the caller that passes no reason.
function Ledger.LetGo(name, why)
	local s, now = Store(), Wall()
	name = CleanName(name)
	if not s or not now or not name then return end
	local e = FindOpen(s, name)
	if not e then return end
	why = WHY[why] and why or "expired"
	e.state, e.why, e.doneAt = "letgo", why, now
	Bump(s, "letGo")
	Changed()
end

-- The one moment a favour changes hands that Core does not tell this file
-- about: putting its giver on the never-offer list, which drops their debt
-- there and then (see ns.PutOnNeverList). The sweep that reports a debt
-- running out never sees one that is already gone, so the row stayed owed --
-- counted in the headline, its tooltip promising an offer -- until the next
-- reload called it run out, which is the one thing it was not. So the ledger
-- listens for it itself, around the function every way onto the list goes
-- through: the prompt's shift-right-click, /manners never and the box on the
-- options page all look it up on ns when they run, and this file loads after
-- Core.lua has defined it. Whichever debts were there before the call and are
-- gone after it went with it, on purpose. They are compared by the name Core
-- keeps them under, which is the name rows are kept under (see Load), so how
-- the list matches a typed name is decided in one place only. Were Core to
-- tell this file as well, the row would already be let go, which LetGo finds
-- no open row for and leaves alone. Guarded like everything Core tells it: a
-- ledger that throws must not take the never-offer list with it.
do
	local put = ns.PutOnNeverList
	if type(put) == "function" then
		ns.PutOnNeverList = function(...)
			local before = {}
			for name in pairs(ns.owed or {}) do before[#before + 1] = name end
			local listed = put(...)
			for _, name in ipairs(before) do
				if not (ns.owed and ns.owed[name]) then
					ns.Guard("ledger LetGo", Ledger.LetGo, name, "never")
				end
			end
			return listed
		end
	end
end

-- Everything but the favours still owed, and today's count of buffs given with
-- the list, as the button's tooltip says. Those favours stay because the debt
-- behind each one is still live on the prompt, and because a settle that found
-- no row would count the favour a second time.
--
-- The settles kept for a refusal stay too. A refusal can still arrive for one
-- the list no longer shows, and Core puts that debt back either way; forgetting
-- the settle here left the return counted and the favour with no row, so the
-- next return counted it again. Refused copes with a row that is gone, and the
-- list of settles prunes itself.
function Ledger.Clear()
	local s = Store()
	if not s then return end
	local kept = {}
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" then kept[#kept + 1] = e end
	end
	s.entries = kept
	s.today = nil
	Changed()
end

---------------------------------------------------------------------------
-- reading it back
---------------------------------------------------------------------------

-- Newest first, for one of the window's tabs.
function Ledger.Entries(filter)
	local s = Store()
	local out = {}
	if not s then return out end
	for i = #s.entries, 1, -1 do
		local e = s.entries[i]
		if filter == "favours" then
			if e.kind == "received" then out[#out + 1] = e end
		elseif filter == "given" then
			if e.kind == "given" then out[#out + 1] = e end
		else
			out[#out + 1] = e
		end
	end
	return out
end

-- Why nothing new can reach the list right now, or nil when it can: "off" for
-- an addon switched off, "nothing" for a character the prompt has nothing to
-- cast on, "owedoff" for favours not being watched for. The gates NoteFavour
-- and the prompt pass before this file hears of anything, asked the same way,
-- so the window never promises a row that cannot come. Asked, never stored:
-- every one of them is a setting or a spell book that can change under it.
local function Quiet()
	local p = ns.db and ns.db.profile
	if type(p) ~= "table" then return nil end
	if not p.enabled then return "off" end
	local ok, nothing = pcall(function()
		if #ns.CastableBuffs() == 0 then return true end
		local pinned = ns.PinnedBuff()
		return pinned ~= nil and not ns.IsBuffKnown(pinned)
	end)
	if ok and nothing then return "nothing" end
	if type(p.sources) == "table" and not p.sources.owed then return "owedoff" end
	return nil
end
Ledger.Quiet = Quiet

-- Today's numbers from the list, the lifetime ones from the counts. A favour
-- nothing you cast could return is counted apart from the rest, `useless`, and
-- left out of `received`, which is what the headline scores you against.
function Ledger.Summary()
	local s, now = Store(), Wall()
	local out = { received = 0, returned = 0, useless = 0, given = 0, owed = 0,
		totals = { received = 0, returned = 0, letGo = 0, group = 0, strangers = 0 } }
	if not s or not now then return out end
	local today = StartOfToday(now)
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" then out.owed = out.owed + 1 end
		if e.at >= today then
			if e.kind == "received" and e.why == "useless" then
				out.useless = out.useless + 1
			elseif e.kind == "received" then
				out.received = out.received + 1
				if e.state == "returned" then out.returned = out.returned + 1 end
			else
				out.given = out.given + 1
			end
		end
	end
	-- The list keeps only MAX_GIVEN buffs given, so on a busy day the count
	-- kept apart from it is the one that is right. The larger of the two,
	-- because a list from before that count existed has rows it never saw.
	if s.today and s.today.day == today then out.given = math.max(out.given, s.today.given) end
	for _, key in ipairs(TOTALS) do out.totals[key] = s.totals[key] or 0 end
	return out
end

function Ledger.Headline(sum)
	sum = sum or Ledger.Summary()
	if sum.received == 0 then
		return (sum.useless or 0) > 0 and TEXT.TODAY_ONLY_USELESS or TEXT.TODAY_NONE
	end
	if sum.received == 1 then return TEXT.TODAY_ONE:format(sum.returned) end
	return TEXT.TODAY_MANY:format(sum.returned, sum.received)
end

function Ledger.Lifetime(sum)
	local t = (sum or Ledger.Summary()).totals
	return TEXT.LIFETIME:format(t.received, t.returned, t.group, t.strangers)
end

-- The line under the headline: what is still owed and what was given today,
-- each its own sentence, or nothing.
local function Subline(sum)
	local owed = sum.owed == 1 and TEXT.OWED_ONE
		or sum.owed > 1 and TEXT.OWED_MANY:format(sum.owed) or nil
	local gave = sum.given == 1 and TEXT.GAVE_ONE
		or sum.given > 1 and TEXT.GAVE_MANY:format(sum.given) or nil
	if owed and gave then return owed .. "  " .. gave end
	return owed or gave or ""
end

-- For the General tab: the headline and the lifetime counts, or one line saying
-- there is nothing yet.
function Ledger.OptionsText()
	local sum = Ledger.Summary()
	local t = sum.totals
	if t.received == 0 and t.group == 0 and t.strangers == 0 and #Ledger.Entries("all") == 0 then
		return TEXT.OPTIONS_EMPTY
	end
	return Ledger.Headline(sum) .. "\n" .. Ledger.Lifetime(sum)
end

-- For the minimap button's tooltip. AddLine only: every broker display offers
-- that, and not every one offers anything else.
--
-- Left out on a character that is recording nothing and never has: a rogue's
-- tooltip under "Nothing to do" gained a line of zeros and a headline about
-- favours it will never hear of. Kept for one with a history, switched off or
-- not, because those numbers are still true and still theirs.
function Ledger.AddTooltip(tooltip)
	if not (tooltip and tooltip.AddLine) or not Store() then return end
	local sum = Ledger.Summary()
	local quiet = Quiet()
	if (quiet == "off" or quiet == "nothing") and #Ledger.Entries("all") == 0 then
		local t = sum.totals
		if t.received == 0 and t.group == 0 and t.strangers == 0 then return end
	end
	tooltip:AddLine(Ledger.Headline(sum), 1, 0.82, 0)
	tooltip:AddLine(Ledger.Lifetime(sum), 0.62, 0.62, 0.62, true)
end

---------------------------------------------------------------------------
-- the window
--
-- Drawn from the same single white texture the prompt is, for the same reason:
-- an atlas or art file this client lacks renders as a green square, and a solid
-- texture cannot fail. The look follows the prompt's glass panel -- a two-step
-- shadow, a dark translucent body, a hairline of light -- with its accent
-- colour under the title, so the two read as one addon.
---------------------------------------------------------------------------

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOGO = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- Top to bottom: the title band, today's headline and the line under it, the
-- all-time numbers as four tiles, the tabs, seven rows, and a footer with the
-- position in the list and Clear. Seven rather than more because the window has
-- to fit a small UI scale, where the whole screen is under eight hundred units
-- tall; the wheel does the rest.
local WIDTH, HEIGHT = 360, 438
local PAD = 12
local ROWS = 7
local ROW_HEIGHT = 34
local STATS_TOP = -92
local TABS_TOP = -134
local LIST_TOP = -164
local DEFAULT_POINT, DEFAULT_X, DEFAULT_Y = "LEFT", 40, 40
local CLEAR_SECONDS = 3
-- How often an open window redraws for "5 min ago" to become "6 min ago".
local TICK_SECONDS = 15

-- Each state's colour: the prompt's own amber for a favour owed and its group
-- blue for a gift to the group, so a colour means the same thing in both
-- places.
local COLOUR = {
	owed = { 1.00, 0.78, 0.30 },
	returned = { 0.40, 0.86, 0.50 },
	letgo = { 0.50, 0.52, 0.58 },
	group = { 0.34, 0.60, 0.96 },
	stranger = { 0.66, 0.56, 0.94 },
}

local window, rows, offset, filter, lastTop, tickAt, clearArmedUntil

local function Hex(c)
	return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5),
		math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function Badge(label, colour)
	return ("|cff%s%s|r"):format(Hex(colour), label)
end

local function Font()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	local path = LSM and p and LSM:Fetch("font", p.font, true)
	return path or STANDARD_TEXT_FONT
end

local function Solid(parent, layer, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(WHITE)
	return t
end

local function Text(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(Font(), size, "")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, 0.9)
	fs:SetShadowOffset(1, -1)
	fs.size = size
	return fs
end

local function Accent()
	local c = ns.db and ns.db.profile and ns.db.profile.prompt and ns.db.profile.prompt.accentColor
	if type(c) == "table" and type(c[1]) == "number" then return c end
	return { 0.45, 0.4, 0.9, 1 }
end

-- A flat button: a faint plate that brightens under the mouse, and a label.
local function FlatButton(parent, label, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height)
	b.plate = Solid(b, "BACKGROUND")
	b.plate:SetAllPoints()
	b.plate:SetVertexColor(1, 1, 1, 0.06)
	b.label = Text(b, 11)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetText(label)
	b:SetScript("OnEnter", function(self)
		self.plate:SetVertexColor(1, 1, 1, self.selected and 0.2 or 0.13)
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(self.tip, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.plate:SetVertexColor(1, 1, 1, self.selected and 0.16 or 0.06)
		if self.tip then GameTooltip:Hide() end
	end)
	return b
end

local function SavePosition()
	local s = Store()
	if not (s and window) then return end
	local point, _, relPoint, x, y = window:GetPoint()
	if POINTS[point] and POINTS[relPoint] and type(x) == "number" and type(y) == "number" then
		s.window = { point = point, relPoint = relPoint, x = x, y = y }
	end
end

local function Place()
	local s = Store()
	local w = s and s.window
	window:ClearAllPoints()
	if w then
		window:SetPoint(w.point, UIParent, w.relPoint, w.x, w.y)
	else
		-- Off to the left rather than centred. The prompt's own default spot
		-- is the bottom centre, and at a small UI scale a centred window this
		-- tall reached down over it -- in a higher strata, taking the clicks --
		-- so somebody who opened the ledger to watch favours come in could no
		-- longer see or press the prompt that returns them.
		window:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
	end
end

local function Detail(e)
	if e.kind == "given" then
		local spell = SpellName(e.spell) or TEXT.UNKNOWN_SPELL
		local colour = e.to == "group" and COLOUR.group or COLOUR.stranger
		local rest = (e.to == "group" and TEXT.GAVE_GROUP or TEXT.GAVE_STRANGER):format(spell)
		return Badge(TEXT.STATE_GAVE, colour) .. "  " .. rest, colour
	end
	local theirs = {}
	for _, id in ipairs(e.spells) do theirs[#theirs + 1] = SpellName(id) or TEXT.UNKNOWN_SPELL end
	local spells = #theirs > 0 and table.concat(theirs, ", ") or TEXT.UNKNOWN_SPELL
	if e.state == "owed" then
		return Badge(TEXT.STATE_OWED, COLOUR.owed) .. "  " .. spells, COLOUR.owed
	elseif e.state == "returned" then
		local gave = SpellName(e.gave)
		return Badge(TEXT.STATE_RETURNED, COLOUR.returned)
			.. (gave and ("  " .. TEXT.RETURNED_WITH:format(gave)) or ""), COLOUR.returned
	end
	local why = e.why == "useless" and TEXT.LETGO_USELESS
		or e.why == "notkept" and TEXT.LETGO_NOTKEPT
		or e.why == "never" and TEXT.LETGO_NEVER or TEXT.LETGO_EXPIRED
	return Badge(TEXT.STATE_LETGO, COLOUR.letgo) .. "  " .. why, COLOUR.letgo
end

-- What an owed row says in place of "the prompt offers them" while the prompt
-- cannot, or nil while it can. Asked at the moment of hovering, like Quiet(),
-- because every one of these is a switch, a timer or a mount that changes
-- under a window left open. Each question is asked through pcall: this is a
-- tooltip, and a helper that throws must cost the caveat, not the tooltip.
--
-- A snooze and a mount only hold the offer back for a while, so their lines
-- say when it comes. For a favour only a party buff can return it also waits
-- on the giver being in your party, and a line that left that out promised an
-- offer at the end of the snooze or the ride that never came for somebody
-- outside it. Those rows get lines that say both. Switched off, not watching
-- for favours or nothing to cast is no offer at all, party or not.
local function OwedHeldBack(e)
	local ok, quiet = pcall(Quiet)
	quiet = ok and quiet or nil
	if quiet == "off" then return TEXT.TIP_OWED_OFF end
	if quiet == "owedoff" then return TEXT.TIP_OWED_SOURCE_OFF end
	if quiet == "nothing" then return TEXT.TIP_OWED_NOTHING end
	local snoozeLine, mountLine = TEXT.TIP_OWED_SNOOZED, TEXT.TIP_OWED_MOUNTED
	if e.partyOnly then
		if ns.PARTY_IS_SUBGROUP then
			snoozeLine, mountLine = TEXT.TIP_OWED_SNOOZED_SUBGROUP, TEXT.TIP_OWED_MOUNTED_SUBGROUP
		else
			snoozeLine, mountLine = TEXT.TIP_OWED_SNOOZED_PARTY, TEXT.TIP_OWED_MOUNTED_PARTY
		end
	end
	local snoozed, ends = pcall(function()
		return ns.SnoozeLeft and ns.SnoozeLeft() and ns.SnoozeEndsAt()
	end)
	if snoozed and type(ends) == "string" then return snoozeLine:format(ends) end
	local okMounted, mounted = pcall(function()
		return ns.HiddenWhileMounted and ns.HiddenWhileMounted()
	end)
	if okMounted and mounted == true then return mountLine end
	return nil
end

local function RowTooltip(row)
	local e = row.entry
	if not e then return end
	local now = Wall() or e.at
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Coloured(e.name, e.class))
	if e.kind == "given" then
		GameTooltip:AddLine(TEXT.TIP_GAVE:format(SpellName(e.spell) or TEXT.UNKNOWN_SPELL,
			Ledger.Ago(now - e.at)), 1, 1, 1, true)
		GameTooltip:AddLine(e.to == "group" and TEXT.TIP_GAVE_GROUP or TEXT.TIP_GAVE_STRANGER,
			0.7, 0.7, 0.7, true)
	else
		local theirs = {}
		for _, id in ipairs(e.spells) do theirs[#theirs + 1] = SpellName(id) or TEXT.UNKNOWN_SPELL end
		GameTooltip:AddLine(TEXT.TIP_BUFFED:format(#theirs > 0 and table.concat(theirs, ", ")
			or TEXT.UNKNOWN_SPELL, Ledger.Ago(now - e.at)), 1, 1, 1, true)
		if e.times > 1 then GameTooltip:AddLine(TEXT.TIP_TIMES:format(e.times), 0.7, 0.7, 0.7, true) end
		local c = COLOUR[e.state] or COLOUR.letgo
		if e.state == "owed" then
			local line = OwedHeldBack(e)
				or not e.partyOnly and TEXT.TIP_OWED
				or ns.PARTY_IS_SUBGROUP and TEXT.TIP_OWED_SUBGROUP or TEXT.TIP_OWED_PARTY
			GameTooltip:AddLine(line, c[1], c[2], c[3], true)
		elseif e.state == "returned" then
			local took = Duration((e.doneAt or e.at) - e.at)
			local gave = SpellName(e.gave)
			GameTooltip:AddLine(gave and TEXT.TIP_RETURNED_WITH:format(took, gave)
				or TEXT.TIP_RETURNED:format(took), c[1], c[2], c[3], true)
		else
			GameTooltip:AddLine(e.why == "useless" and TEXT.TIP_LETGO_USELESS
				or e.why == "notkept" and TEXT.TIP_LETGO_NOTKEPT
				or e.why == "never" and TEXT.TIP_LETGO_NEVER or TEXT.TIP_LETGO_EXPIRED,
				c[1], c[2], c[3], true)
		end
	end
	GameTooltip:Show()
end

local function BuildRow(i)
	local row = CreateFrame("Button", nil, window)
	local y = LIST_TOP - (i - 1) * ROW_HEIGHT
	row:SetHeight(ROW_HEIGHT - 2)
	row:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
	row:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD - 8, y)

	-- Alternate rows a shade apart, so the eye can follow one across.
	row.back = Solid(row, "BACKGROUND")
	row.back:SetAllPoints()
	row.back:SetVertexColor(1, 1, 1, i % 2 == 1 and 0.035 or 0.015)

	row.stripe = Solid(row, "BORDER")
	row.stripe:SetWidth(3)
	row.stripe:SetPoint("TOPLEFT")
	row.stripe:SetPoint("BOTTOMLEFT")

	row.iconBack = Solid(row, "BORDER")
	row.iconBack:SetSize(24, 24)
	row.iconBack:SetPoint("LEFT", row, "LEFT", 9, 0)
	row.iconBack:SetVertexColor(0, 0, 0, 0.85)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(22, 22)
	row.icon:SetPoint("CENTER", row.iconBack, "CENTER")
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.when = Text(row, 10)
	row.when:SetJustifyH("RIGHT")
	row.when:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
	row.when:SetTextColor(0.6, 0.6, 0.62)

	row.name = Text(row, 12)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 40, -3)
	row.name:SetPoint("RIGHT", row, "RIGHT", -70, 0)

	row.detail = Text(row, 11)
	row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 40, 3)
	row.detail:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.detail:SetTextColor(0.82, 0.82, 0.84)

	-- A wash of the row's colour when something new arrives at the top, so the
	-- entry that just happened is the one the eye lands on.
	row.flash = Solid(row, "ARTWORK", 1)
	row.flash:SetAllPoints()
	row.flash:SetBlendMode("ADD")
	row.flash:SetAlpha(0)
	row.flashAnim = row.flash:CreateAnimationGroup()
	local fade = row.flashAnim:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.35)
	fade:SetToAlpha(0)
	fade:SetDuration(1.2)
	fade:SetSmoothing("OUT")

	row:SetHighlightTexture(WHITE, "ADD")
	local hl = row:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.05) end
	row:SetScript("OnEnter", RowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- The wheel over a row scrolls the list, as it does over the gaps between
	-- them. Asked for on the row itself rather than left to reach the window:
	-- the rows cover nearly all of the list, and a wheel that only worked in
	-- the two-pixel seams between them would read as no wheel at all.
	row:EnableMouseWheel(true)
	row:SetScript("OnMouseWheel", function(_, delta) Ledger.Scroll(-(delta or 0)) end)
	row:Hide()
	return row
end

local function Paint(row, e, now)
	row.entry = e
	-- Not `a and b or c`: a gift whose spell the client would not name has a
	-- nil `spell`, and the collapse then reached for a favour's spell list on a
	-- row that has none.
	local id
	if e.kind == "given" then id = e.spell else id = e.spells[1] end
	row.icon:SetTexture(SpellIcon(id))
	row.name:SetText(Coloured(e.name, e.class))
	row.when:SetText(Ledger.Ago(now - e.at))
	local detail, colour = Detail(e)
	row.detail:SetText(detail)
	row.stripe:SetVertexColor(colour[1], colour[2], colour[3], 0.9)
	row.flash:SetVertexColor(colour[1], colour[2], colour[3], 1)
	-- Let go is over and done with: dimmed, so what still needs doing and what
	-- went well stand out from it.
	row:SetAlpha(e.kind == "received" and e.state == "letgo" and 0.62 or 1)
	row:Show()
end

local function SetFilter(key)
	filter = FILTERS[key] and key or "all"
	local s = Store()
	if s then s.filter = filter end
	-- A different tab has a different entry on top, and that is not something
	-- having just happened.
	offset, lastTop = 0, nil
	for _, tab in ipairs(window.tabs) do
		tab.selected = tab.key == filter
		tab.plate:SetVertexColor(1, 1, 1, tab.selected and 0.16 or 0.06)
		tab.underline:SetShown(tab.selected)
		tab.label:SetTextColor(tab.selected and 1 or 0.7, tab.selected and 1 or 0.7,
			tab.selected and 1 or 0.72)
	end
end

local function DisarmClear()
	clearArmedUntil = nil
	if window then window.clear.label:SetText(TEXT.CLEAR) end
end

-- What an empty tab says: how a row would come to be there, or, while none can,
-- why not. The owed toggle stops favours and nothing else, so the tab of buffs
-- given keeps its ordinary line under it.
local function EmptyText(key)
	local quiet = Quiet()
	if quiet == "off" then return TEXT.EMPTY_OFF end
	if quiet == "nothing" then return TEXT.EMPTY_NOTHING end
	if key == "given" then return TEXT.EMPTY_GIVEN end
	if quiet == "owedoff" then return TEXT.EMPTY_OWED_OFF end
	return key == "favours" and TEXT.EMPTY_FAVOURS or TEXT.EMPTY_ALL
end

function Render()
	if not (window and window:IsShown()) then return end
	local now = Wall()
	if not now then return end
	local list = Ledger.Entries(filter)
	local sum = Ledger.Summary()

	window.headline:SetText(Ledger.Headline(sum))
	window.subline:SetText(Subline(sum))
	for _, stat in ipairs(window.stats) do
		stat.value:SetText(tostring(sum.totals[stat.key] or 0))
	end

	local maxOffset = math.max(0, #list - ROWS)
	offset = math.min(math.max(0, offset or 0), maxOffset)
	window.showing:SetShown(#list > 0)
	window.showing:SetText(TEXT.SHOWING:format(offset + 1, math.min(#list, offset + ROWS), #list))
	for i = 1, ROWS do
		local e = list[offset + i]
		if e then Paint(rows[i], e, now) else
			rows[i].entry = nil
			rows[i]:Hide()
		end
	end

	window.empty:SetShown(#list == 0)
	window.empty:SetText(EmptyText(filter))

	-- The scroll bar: a thumb the share of the track the rows on screen are of
	-- the whole list, only when there is more than one screen of it.
	local scrolls = #list > ROWS
	window.track:SetShown(scrolls)
	window.thumb:SetShown(scrolls)
	if scrolls then
		local trackHeight = ROWS * ROW_HEIGHT - 2
		local thumbHeight = math.max(18, trackHeight * ROWS / #list)
		local y = (trackHeight - thumbHeight) * offset / maxOffset
		window.thumb:SetHeight(thumbHeight)
		window.thumb:ClearAllPoints()
		window.thumb:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD + 2, LIST_TOP - y)
	end

	-- Something new at the top since the last paint, and the top is on screen.
	local top = list[1]
	if top and lastTop ~= nil and top ~= lastTop and offset == 0 then
		rows[1].flashAnim:Stop()
		rows[1].flashAnim:Play()
	end
	lastTop = top or false
end

-- Rows, not pixels: one notch of the wheel moves the list by one entry.
function Ledger.Scroll(delta)
	offset = (offset or 0) + (delta or 0)
	Render()
end

local function Build()
	window = CreateFrame("Frame", "MannersLedger", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	-- Comes to the front of its strata when clicked, and Show raises it, so
	-- another window in the same strata that was opened first does not keep
	-- it underneath. The options button shuts the addon's own options window
	-- before opening this one; this covers whatever else is up. Asked for
	-- rather than assumed, as the rest of the client's frame API is here.
	if window.SetToplevel then window:SetToplevel(true) end
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:EnableMouseWheel(true)
	window:RegisterForDrag("LeftButton")
	window:Hide()
	Place()
	-- Escape closes it, as it does every other window of this kind.
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "MannersLedger")
	end

	local shadowOuter = Solid(window, "BACKGROUND", -8)
	shadowOuter:SetPoint("TOPLEFT", -6, 6)
	shadowOuter:SetPoint("BOTTOMRIGHT", 6, -6)
	shadowOuter:SetVertexColor(0, 0, 0, 0.18)
	local shadowInner = Solid(window, "BACKGROUND", -7)
	shadowInner:SetPoint("TOPLEFT", -2, 2)
	shadowInner:SetPoint("BOTTOMRIGHT", 2, -2)
	shadowInner:SetVertexColor(0, 0, 0, 0.32)
	local body = Solid(window, "BACKGROUND", -6)
	body:SetAllPoints()
	body:SetVertexColor(0.04, 0.04, 0.06, 0.94)

	-- The title band, a shade lighter, with the accent drawn under it.
	local band = Solid(window, "BACKGROUND", -5)
	band:SetPoint("TOPLEFT")
	band:SetPoint("TOPRIGHT")
	band:SetHeight(30)
	band:SetVertexColor(1, 1, 1, 0.045)
	local hair = Solid(window, "BORDER", 1)
	hair:SetPoint("TOPLEFT")
	hair:SetPoint("TOPRIGHT")
	hair:SetHeight(1)
	hair:SetVertexColor(1, 1, 1, 0.12)
	window.accent = Solid(window, "BORDER", 2)
	window.accent:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -30)
	window.accent:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -30)
	window.accent:SetHeight(1)

	local logo = window:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(LOGO)
	logo:SetSize(18, 18)
	logo:SetPoint("TOPLEFT", window, "TOPLEFT", PAD - 2, -6)
	local title = Text(window, 13)
	title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
	title:SetText(TEXT.TITLE)
	title:SetTextColor(1, 0.82, 0)

	local close = FlatButton(window, TEXT.CLOSE, 22, 20)
	close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
	close.plate:SetVertexColor(1, 1, 1, 0)
	close.tip = TEXT.CLOSE_TIP
	close:SetScript("OnClick", function() window:Hide() end)
	window.close = close

	window.headline = Text(window, 14)
	window.headline:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -42)
	window.headline:SetPoint("RIGHT", window, "RIGHT", -PAD, 0)
	window.subline = Text(window, 11)
	window.subline:SetPoint("TOPLEFT", window.headline, "BOTTOMLEFT", 0, -4)
	window.subline:SetPoint("RIGHT", window, "RIGHT", -PAD, 0)
	window.subline:SetTextColor(0.7, 0.7, 0.72)

	-- The all-time numbers, as four tiles rather than a sentence: a line
	-- carrying four counts does not fit the width once the numbers grow, and a
	-- number is read faster standing on its own. Each tile's number takes the
	-- colour its rows use below.
	local caption = Text(window, 9)
	caption:SetPoint("BOTTOMLEFT", window, "TOPLEFT", PAD, STATS_TOP + 3)
	caption:SetText(TEXT.ALL_TIME)
	caption:SetTextColor(0.55, 0.55, 0.58)
	window.stats = {}
	local gap = 4
	local tileWidth = (WIDTH - 2 * PAD - 3 * gap) / 4
	for i, def in ipairs({
		{ key = "received", label = TEXT.STAT_RECEIVED, colour = COLOUR.owed },
		{ key = "returned", label = TEXT.STAT_RETURNED, colour = COLOUR.returned },
		{ key = "group", label = TEXT.STAT_GROUP, colour = COLOUR.group },
		{ key = "strangers", label = TEXT.STAT_STRANGERS, colour = COLOUR.stranger },
	}) do
		local x = PAD + (i - 1) * (tileWidth + gap)
		local plate = Solid(window, "BORDER")
		plate:SetSize(tileWidth, 34)
		plate:SetPoint("TOPLEFT", window, "TOPLEFT", x, STATS_TOP)
		plate:SetVertexColor(1, 1, 1, 0.04)
		local tick = Solid(window, "BORDER", 1)
		tick:SetSize(tileWidth, 1)
		tick:SetPoint("TOPLEFT", plate, "TOPLEFT")
		tick:SetVertexColor(def.colour[1], def.colour[2], def.colour[3], 0.7)
		local value = Text(window, 15)
		value:SetPoint("TOP", plate, "TOP", 0, -3)
		value:SetJustifyH("CENTER")
		value:SetTextColor(def.colour[1], def.colour[2], def.colour[3])
		local label = Text(window, 9)
		label:SetPoint("BOTTOM", plate, "BOTTOM", 0, 3)
		label:SetJustifyH("CENTER")
		label:SetText(def.label)
		label:SetTextColor(0.62, 0.62, 0.65)
		window.stats[i] = { key = def.key, value = value }
	end

	window.tabs = {}
	local tabX = PAD
	for _, def in ipairs({
		{ key = "all", label = TEXT.TAB_ALL, width = 92 },
		{ key = "favours", label = TEXT.TAB_FAVOURS, width = 82 },
		{ key = "given", label = TEXT.TAB_GIVEN, width = 120 },
	}) do
		local tab = FlatButton(window, def.label, def.width, 20)
		tab:SetPoint("TOPLEFT", window, "TOPLEFT", tabX, TABS_TOP)
		tab.key = def.key
		tab.underline = Solid(tab, "BORDER", 2)
		tab.underline:SetPoint("BOTTOMLEFT")
		tab.underline:SetPoint("BOTTOMRIGHT")
		tab.underline:SetHeight(2)
		tab:SetScript("OnClick", function(self)
			SetFilter(self.key)
			Render()
		end)
		window.tabs[#window.tabs + 1] = tab
		tabX = tabX + def.width + 4
	end

	rows = {}
	for i = 1, ROWS do rows[i] = BuildRow(i) end
	window.rows = rows

	window.empty = Text(window, 12)
	window.empty:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + 16, LIST_TOP - 40)
	window.empty:SetPoint("RIGHT", window, "RIGHT", -PAD - 16, 0)
	window.empty:SetJustifyH("CENTER")
	window.empty:SetWordWrap(true)
	window.empty:SetTextColor(0.6, 0.6, 0.64)

	window.track = Solid(window, "BORDER")
	window.track:SetWidth(3)
	window.track:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD + 2, LIST_TOP)
	window.track:SetHeight(ROWS * ROW_HEIGHT - 2)
	window.track:SetVertexColor(1, 1, 1, 0.06)
	window.thumb = Solid(window, "ARTWORK")
	window.thumb:SetWidth(3)

	-- The footer: where the rows on screen sit in the list, and Clear.
	local rule = Solid(window, "BORDER")
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 34)
	rule:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 34)
	rule:SetVertexColor(1, 1, 1, 0.07)
	window.showing = Text(window, 10)
	window.showing:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 14)
	window.showing:SetTextColor(0.55, 0.55, 0.58)

	local clear = FlatButton(window, TEXT.CLEAR, 132, 20)
	clear:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 9)
	clear.tip = TEXT.CLEAR_TIP
	-- Two presses, the second inside a few seconds of the first, rather than a
	-- confirmation dialog: the list is the only thing it takes, and a dialog
	-- over a window this small is more ceremony than the loss deserves.
	clear:SetScript("OnClick", function(self)
		if clearArmedUntil and GetTime() <= clearArmedUntil then
			DisarmClear()
			Ledger.Clear()
		else
			clearArmedUntil = GetTime() + CLEAR_SECONDS
			self.label:SetText(TEXT.CLEAR_ARMED)
		end
	end)
	window.clear = clear

	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- The position is this file's to keep, in the ledger. Left user-placed,
		-- the client's layout cache would keep a second copy of it and the two
		-- could disagree about where the window belongs.
		self:SetUserPlaced(false)
		SavePosition()
	end)
	window:SetScript("OnMouseWheel", function(_, delta) Ledger.Scroll(-(delta or 0)) end)
	window:SetScript("OnHide", function()
		DisarmClear()
		GameTooltip:Hide()
	end)
	-- Only while it is open: a shown frame is the only kind OnUpdate runs on.
	window:SetScript("OnUpdate", function(_, elapsed)
		tickAt = (tickAt or 0) + (elapsed or 0)
		if clearArmedUntil and GetTime() > clearArmedUntil then DisarmClear() end
		if tickAt >= TICK_SECONDS then
			tickAt = 0
			Render()
		end
	end)

	window.fadeIn = window:CreateAnimationGroup()
	local fade = window.fadeIn:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.15)
	fade:SetSmoothing("OUT")

	local s = Store()
	filter = s and s.filter or "all"
	SetFilter(filter)
end

function Ledger.Show()
	if not window then Build() end
	local c = Accent()
	window.accent:SetVertexColor(c[1], c[2], c[3], 0.9)
	window.thumb:SetVertexColor(c[1], c[2], c[3], 0.8)
	for _, tab in ipairs(window.tabs) do tab.underline:SetVertexColor(c[1], c[2], c[3], 1) end
	offset, lastTop, tickAt = 0, nil, 0
	window:Show()
	if window.Raise then window:Raise() end
	window.fadeIn:Stop()
	window.fadeIn:Play()
	Render()
end

function Ledger.Hide()
	if window then window:Hide() end
end

function Ledger.Toggle()
	if window and window:IsShown() then Ledger.Hide() else Ledger.Show() end
end

-- For the scenarios, which have to read what is on screen.
function Ledger.Window()
	return window
end
