-- Manners -- milestones: a small layer of achievements over the favour ledger.
--
-- The game's own achievement window is closed to addons, so these are Manners'
-- own: a dozen or so marks of good manners, each read from what the ledger
-- already records (Ledger.lua) or from a count kept here beside it. They are
-- listed on the ledger window's fourth tab, and a new one -- or a new title --
-- gets a toast drawn here in the manner of the game's achievement alert, with
-- one line in chat.
--
-- Quiet by design. One switch (Start here, under Favour ledger) turns all of
-- it off: no toast, no tab, no chat line for a milestone, and nothing counted
-- while it is off (a new title keeps its one line in chat, which is the
-- ledger's own and older than these: Ledger.lua, Announce); what was earned is
-- kept for when it is switched back on. A toast never shows
-- in a fight (it waits for the end), never over the prompt, one at a time and
-- at most one a minute, and goes after a few seconds or at a click. A ledger
-- that was already long when milestones arrived takes what it has earned
-- without a toast, as it took its titles: one line in chat says how many.
--
-- Never a reward for spam. Nothing counts presses: a stranger buffed again
-- before the buff would have run out is the same stranger, the same person
-- counts once a day towards "the same person ten times", and what is counted
-- is counted only once the server had its chance to refuse the cast (the
-- ledger's own wait, PROMOTE_SECONDS). Switching the feature off and on earns
-- nothing: what was passed meanwhile is marked without a toast.
--
-- Per character, in db.char.milestones, like the ledger. A profile reset does
-- not touch it, and neither does the ledger's Clear, which keeps the all-time
-- counts these are read from. The week without a debt is the one read from
-- the ledger's rows: a row of the last week that Clear or the ledger's trim
-- takes is told here first (M.Dropped) and kept in `week`.
--
--   milestones.seeded   true once the ledger's past has been read
--   milestones.earned   id -> when (the wall clock); negative for one already
--                       passed when milestones began or were switched back on
--   milestones.n        counts kept here: strangers, swift, asked, raid, res,
--                       cure, courtesy
--   milestones.people   name -> { n = days a favour was returned to them, day }
--   milestones.classes  class token -> true, of people a favour was returned to
--   milestones.today    { day, n, names }: who was returned a favour today
--   milestones.lately   stranger -> when the buff you gave them runs out
--   milestones.due      the settles still inside the refusal wait, as { kind,
--                       name, at }: what a reload in those seconds would lose
--   milestones.week     { kept = when each favour was received that was
--                       returned and whose row the ledger has dropped since,
--                       broke = when the latest one left unreturned was }
--
-- What the other features tell it, each one call where their cast is known to
-- have landed: ns.Milestones.Note("res"), Note("cure"), Note("courtesy").
--
-- Every one of them earned opens the hall of fame (Hall.lua), which reads
-- Tally and LastEarned from here and is told by Evaluate when the last lands.

local _, ns = ...
local L = ns.L

local Ledger = ns.Ledger
local K = Ledger and Ledger.Kit
if not K then return end

local M = {}
ns.Milestones = M

local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local plain = ns.plain

---------------------------------------------------------------------------
-- text
---------------------------------------------------------------------------

local TEXT = {
	-- The toast's small line over the name.
	HEAD_MILESTONE = L["Milestone earned"],
	HEAD_TITLE = L["New title"],
	-- The one chat line a new milestone gets: its name, then what earned it.
	EARNED = L["A milestone for your manners: |cffffd100%s|r. %s"],
	-- Once, the first time milestones meet a ledger with a past.
	SEEDED_ONE = L["Manners now keeps milestones, and your ledger had already earned 1. It is on the Milestones tab of the favour ledger (|cffffd100/manners ledger|r)."],
	SEEDED_MANY = L["Manners now keeps milestones, and your ledger had already earned %d. They are on the Milestones tab of the favour ledger (|cffffd100/manners ledger|r)."],

	-- A row's badge.
	BADGE_EARNED = L["Earned"],
	BADGE_PROGRESS = L["%d of %d"],
	BADGE_NOT_YET = L["Not yet"],
	BADGE_HIDDEN = L["Hidden"],
	-- A hidden milestone's name and line until it is earned.
	HIDDEN_NAME = "?",
	HIDDEN_DESC = L["A hidden milestone. Good manners will find it."],
	-- In place of a date, for one passed before milestones were kept.
	BEFORE = L["before %s"],
	TIP_EARNED = L["Earned on %s."],
	TIP_BEFORE = L["Earned before %s, when Manners began keeping milestones."],
	TIP_PROGRESS = L["%d of %d so far."],

	LINK = L["Link in chat"],
	LINK_TIP = L["Puts one line about this milestone in your chat box. Nothing is sent until you press Enter."],
	-- The line itself: plain text, the milestone's name and what earned it.
	LINK_LINE = L["Manners milestone earned: %s (%s)"],

	-- /manners debug and the check-up.
	LINE_OFF = L["milestones: switched off -- nothing is counted for them, and what was earned is kept."],
	LINE_COUNT = L["milestones: %d of %d earned."],
	-- The switch by the name it has on the options page.
	LINE_TOAST_OFF = L["milestones: \"%s\" is off, so a new one is said in chat only."]:format(L["Show it on screen too"]),
	LINE_HELD_FIGHT = L["milestones: %d toast(s) waiting for the fight to end."],
	LINE_HELD_MINUTE = L["milestones: %d toast(s) waiting -- at most one a minute."],
	LINE_HELD_SHOWING = L["milestones: %d toast(s) waiting for the one on screen."],
}
M.TEXT = TEXT

---------------------------------------------------------------------------
-- the milestones
--
-- `value(st, sum)` is how far along, `goal` where it is earned; a goal above
-- one shows its progress. `hidden` ones read "?" until earned. `feature` says
-- whether this character can earn it at all (a class with no resurrection is
-- not shown one), and one without it needs a buff for somebody else (Available);
-- one already earned is always listed. Icons are file ids
-- that every client has (ManifestInterfaceData of all five builds).
---------------------------------------------------------------------------

local function Returned(_, sum) return sum.totals.returned or 0 end
local function Kept(key) return function(st) return st.n[key] or 0 end end

local function BestPerson(st)
	local best = 0
	for _, p in pairs(st.people) do
		if p.n > best then best = p.n end
	end
	return best
end

local function Classes(st)
	local n = 0
	for _ in pairs(st.classes) do n = n + 1 end
	return n
end

local DayKey -- below

local function Today(st, _, now)
	if now and st.today.day == DayKey(now) then return st.today.n end
	return 0
end

local WeekKept -- below

local LIST = {
	{ id = "first", icon = 134141, goal = 1, value = Returned,
		name = L["Much Obliged"], desc = L["Return your first favour."] },
	{ id = "asked", icon = 134327, goal = 1, value = Kept("asked"),
		name = L["You Only Had to Ask"], desc = L["Answer a request made in chat."] },
	{ id = "classes", icon = 135946, goal = 5, value = Classes,
		name = L["All Walks of Life"], desc = L["Return favours to people of five different classes."] },
	{ id = "day10", icon = 133471, goal = 10, value = Today,
		name = L["Thank You, Everyone"], desc = L["Return favours to ten different people in one day."] },
	{ id = "regular", icon = 135453, goal = 10, value = BestPerson,
		name = L["Old Acquaintance"], desc = L["Thank the same person on ten different days."] },
	{ id = "strangers", icon = 136078, goal = 100, value = Kept("strangers"),
		name = L["The Kindness of Strangers"], desc = L["Buff a hundred strangers unprompted."],
		note = L["The same stranger counts again only once the buff you gave would have run out."] },
	{ id = "hundred", icon = 135908, goal = 100, value = Returned,
		name = L["A Hundred Thank-Yous"], desc = L["Return a hundred favours."] },
	{ id = "res", icon = 135955, goal = 1, value = Kept("res"),
		feature = function() return ns.Resurrect ~= nil and ns.Resurrect.Has ~= nil and ns.Resurrect.Has() == true end,
		name = L["Back on Your Feet"], desc = L["Bring somebody back to life through the prompt."] },
	{ id = "cure", icon = 135949, goal = 1, value = Kept("cure"),
		feature = function() return ns.ClassHasCures ~= nil and ns.ClassHasCures() == true end,
		name = L["A Clean Bill of Health"], desc = L["Cure somebody through the prompt."] },
	{ id = "courtesy", icon = 132794, goal = 1, value = Kept("courtesy"),
		feature = function()
			local class = ns.caps and ns.caps.class
			return ns.Courtesy ~= nil and (class == "MAGE" or class == "WARLOCK")
		end,
		name = L["At Your Service"], desc = L["Conjure, port or summon on request."] },
	{ id = "swift", icon = 134376, goal = 1, value = Kept("swift"), hidden = true,
		name = L["Quick to Thank"], desc = L["Return a favour within ten seconds."] },
	{ id = "raid", icon = 135941, goal = 1, value = Kept("raid"), hidden = true,
		name = L["Nobody Left Out"], desc = L["Give one of your buffs to everybody in your raid in one sitting."] },
	{ id = "week", icon = 133743, goal = 1, hidden = true,
		value = function(st, sum, now) return WeekKept(now) and 1 or 0 end,
		name = L["A Week Without a Debt"],
		desc = L["Return every favour for a week: ten or more, on at least five days, none left unreturned."] },
}
M.LIST = LIST

local BY_ID = {}
for _, def in ipairs(LIST) do BY_ID[def.id] = def end

-- The counts kept here, and which of them another feature may bump (Note).
local COUNTS = { strangers = true, swift = true, asked = true, raid = true, res = true, cure = true, courtesy = true }
local NOTES = { res = true, cure = true, courtesy = true }

-- A favour returned this soon after it arrived is "Quick to Thank".
local SWIFT_SECONDS = 10
M.SWIFT_SECONDS = SWIFT_SECONDS
-- How long a stranger stays "the same stranger" when the client does not say
-- how long the buff lasts, and the least and most that is ever taken.
local SAME_DEFAULT, SAME_MIN, SAME_MAX = 1800, 300, 7200
-- People remembered for "the same person ten times"; the least-met go first.
local MAX_PEOPLE = 300
-- Strangers remembered as recently buffed, pruned as their buffs run out.
local MAX_LATELY = 400
-- Settles remembered across a reload while they wait out the refusal: a few
-- seconds' worth of presses, never more.
local MAX_DUE = 20
-- One sitting, for "everybody in your raid", and the smallest raid it means.
local SITTING_SECONDS = 900
local RAID_LEAST = 10
-- The week: how far back, how many favours and on how many days at least.
local WEEK_SECONDS, WEEK_FAVOURS, WEEK_DAYS = 7 * 86400, 10, 5
-- How many returned favours of the week are remembered past their rows.
local MAX_KEPT = 300

-- Toasts: seconds fading in, held and fading out; the gap kept between two;
-- and how many may wait (more than that are said in chat only).
local TOAST_IN, TOAST_HOLD, TOAST_OUT = 0.3, 5.5, 0.7
local TOAST_GAP = 60
-- How often a toast on screen looks whether the prompt has come up under it.
local TOAST_LOOK = 0.2
local TOAST_QUEUE = 4
M.TOAST_GAP = TOAST_GAP
M.TOAST_SECONDS = TOAST_IN + TOAST_HOLD + TOAST_OUT

-- The game's achievement fanfare where the client has it (SoundKitEntry 12891:
-- Mists and retail), and the level-up fanfare, which all five have, elsewhere.
local SOUND = { mists = 12891, mainline = 12891 }
local SOUND_ELSE = 888

---------------------------------------------------------------------------
-- the settings and the store
---------------------------------------------------------------------------

local function Setting(key)
	local p = ns.db and ns.db.profile
	local m = p and p.milestones
	if type(m) ~= "table" then return true end
	return m[key] ~= false
end

local function On()
	return Setting("enabled")
end
M.On = On

local function Count(v)
	if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return 0 end
	return math.floor(v)
end

-- The calendar day a moment falls on, on this computer's clock, as a key.
function DayKey(t)
	local ok, key = pcall(_G.date, "%Y%m%d", t)
	return ok and type(key) == "string" and key or "?"
end

local function DateText(t)
	local ok, text = pcall(_G.date, "%Y-%m-%d", t)
	return ok and type(text) == "string" and text or ""
end

local store

-- Whatever is on disk, made into what the readers below can trust.
local function Repair(char)
	local st = char.milestones
	if type(st) ~= "table" then
		st = {}
		char.milestones = st
	end
	local earned = {}
	if type(st.earned) == "table" then
		for id, at in pairs(st.earned) do
			if BY_ID[id] and type(at) == "number" and at == at and at ~= 0 and math.abs(at) ~= math.huge then
				earned[id] = at
			end
		end
	end
	st.earned = earned
	local n, old = {}, type(st.n) == "table" and st.n or {}
	for key in pairs(COUNTS) do n[key] = Count(old[key]) end
	st.n = n
	local people = {}
	if type(st.people) == "table" then
		for name, p in pairs(st.people) do
			if type(name) == "string" and type(p) == "table" and Count(p.n) > 0 then
				people[name] = { n = Count(p.n), day = type(p.day) == "string" and p.day or nil }
			end
		end
	end
	st.people = people
	local classes = {}
	if type(st.classes) == "table" then
		for class, on in pairs(st.classes) do
			if on == true and type(class) == "string" and #class <= 20 and class:find("^%u+$") then classes[class] = true end
		end
	end
	st.classes = classes
	local today, names, count = st.today, {}, 0
	if type(today) == "table" and type(today.day) == "string" and type(today.names) == "table" then
		for name, on in pairs(today.names) do
			if on == true and type(name) == "string" then
				names[name] = true
				count = count + 1
			end
		end
		st.today = { day = today.day, names = names, n = count }
	else
		st.today = { day = "", names = {}, n = 0 }
	end
	local lately = {}
	if type(st.lately) == "table" then
		for name, untilAt in pairs(st.lately) do
			if type(name) == "string" and type(untilAt) == "number" and untilAt == untilAt then lately[name] = untilAt end
		end
	end
	st.lately = lately
	local due = {}
	if type(st.due) == "table" then
		for i = 1, math.min(#st.due, MAX_DUE) do
			local d = st.due[i]
			if type(d) == "table" and (d.kind == "received" or d.kind == "given") and type(d.name) == "string"
				and type(d.at) == "number" and d.at == d.at then
				due[#due + 1] = { kind = d.kind, name = d.name, at = d.at }
			end
		end
	end
	st.due = due
	local week, kept = type(st.week) == "table" and st.week or {}, {}
	if type(week.kept) == "table" then
		for i = math.max(1, #week.kept - MAX_KEPT + 1), #week.kept do
			local at = week.kept[i]
			if type(at) == "number" and at == at then kept[#kept + 1] = at end
		end
	end
	st.week = { kept = kept, broke = type(week.broke) == "number" and week.broke == week.broke and week.broke or nil }
	st.seeded = st.seeded == true
	store = st
	return st
end

local function Store()
	local char = ns.db and ns.db.char
	if type(char) ~= "table" then return nil end
	if store == nil or char.milestones ~= store then return Repair(char) end
	return store
end

---------------------------------------------------------------------------
-- counting
---------------------------------------------------------------------------

-- One more day on which this person's favour was returned.
local function MetAgain(st, name, day)
	local p = st.people[name]
	if p then
		if p.day ~= day then
			p.n, p.day = p.n + 1, day
		end
		return
	end
	local count, least, leastName = 0, nil, nil
	for other, q in pairs(st.people) do
		count = count + 1
		if not least or q.n < least then least, leastName = q.n, other end
	end
	if count >= MAX_PEOPLE and leastName then st.people[leastName] = nil end
	st.people[name] = { n = 1, day = day }
end

local function ThankedToday(st, name, day)
	if st.today.day ~= day then st.today = { day = day, names = {}, n = 0 } end
	if not st.today.names[name] then
		st.today.names[name] = true
		st.today.n = st.today.n + 1
	end
end

-- How long the buff that went out lasts, for "the same stranger".
local function SameFor(spell)
	local seconds = spell and type(ns.SPELL_SECONDS) == "table" and ns.SPELL_SECONDS[spell]
	if type(seconds) ~= "number" or seconds <= 0 then seconds = SAME_DEFAULT end
	return math.min(SAME_MAX, math.max(SAME_MIN, seconds))
end

-- A stranger buffed: one more, unless the last buff they had of you would
-- still be on them.
local function Stranger(st, name, spell, now)
	local untilAt = st.lately[name]
	local fresh = not untilAt or untilAt <= now
	st.lately[name] = math.max(untilAt or 0, now + SameFor(spell))
	if not fresh then return end
	st.n.strangers = st.n.strangers + 1
	local count = 0
	for _ in pairs(st.lately) do count = count + 1 end
	if count > MAX_LATELY then
		for other, at in pairs(st.lately) do
			if at <= now then st.lately[other] = nil end
		end
	end
end

-- Settles waiting out the server's refusal, as a new title does.
local waiting = {}

-- Whether this row of the ledger is still inside that wait.
local function Unsettled(e)
	for _, w in ipairs(waiting) do
		if w.entry == e then return true end
	end
	return false
end

-- Whether a spell given was a resurrection (Resurrect.lua files its casts in
-- the ledger as something given): somebody brought back, not somebody buffed.
local function IsRes(spell)
	local R = ns.Resurrect
	return R ~= nil and R.IsSpell ~= nil and R.IsSpell(spell) == true
end

-- This session's casts on the raid, per spell: who each reached and when.
-- Never saved: a sitting does not outlast a reload.
local sitting = {}

-- One of your buffs on `names` (the one it was cast on and, for a group cast,
-- everybody else it reached) in a raid of `size`. Earned when one buff's
-- casts inside the sitting have reached everybody but you: each person once,
-- however many casts reached them, and never yourself. `spell` is the buff's
-- key where the press said it (M.Settled), so the group version, the single
-- one and a lower rank for somebody low fill one sitting; the spell's id
-- only where no key came with the settle.
local function Sat(st, spell, names, size, clock)
	local key = spell or 0
	local cast = sitting[key]
	if not cast then
		cast = {}
		sitting[key] = cast
	end
	for _, name in ipairs(names) do
		if not ns.IsPlayerName(name) then cast[name] = clock end
	end
	local total = 0
	for other, at in pairs(cast) do
		if clock - at > SITTING_SECONDS then cast[other] = nil else total = total + 1 end
	end
	if size >= RAID_LEAST and total >= size - 1 then st.n.raid = 1 end
end

-- Whether the last week's favours were all returned (LIST, "week"): read from
-- the ledger's rows. A favour nothing could return, or one there was nothing
-- left to give for, is not scored, as the ledger's own headline leaves it out.
function WeekKept(now)
	if not now then return false end
	local favours, days, dayCount = 0, {}, 0
	-- What the ledger no longer has a row for (M.Dropped): a favour left
	-- unreturned inside the week still bars it, and one returned still counts.
	local st = Store()
	local week = st and st.week
	if week then
		if week.broke and week.broke >= now - WEEK_SECONDS then return false end
		for _, at in ipairs(week.kept) do
			if at >= now - WEEK_SECONDS then
				favours = favours + 1
				local day = DayKey(at)
				if not days[day] then
					days[day] = true
					dayCount = dayCount + 1
				end
			end
		end
	end
	for _, e in ipairs(Ledger.Entries("favours")) do
		if e.at >= now - WEEK_SECONDS and e.state ~= "back" and e.why ~= "useless" and e.why ~= "covered" then
			-- Returned, and past the server's refusal: one still inside its
			-- wait may yet go back to owed.
			if e.state ~= "returned" or Unsettled(e) then return false end
			favours = favours + 1
			local day = DayKey(e.at)
			if not days[day] then
				days[day] = true
				dayCount = dayCount + 1
			end
		end
	end
	return favours >= WEEK_FAVOURS and dayCount >= WEEK_DAYS
end

-- A favour returned (`e` is the ledger's row), counted.
local function CountReturn(st, e, now)
	local day = DayKey(e.doneAt or now)
	MetAgain(st, e.name, day)
	ThankedToday(st, e.name, day)
	if e.class then st.classes[e.class] = true end
	if e.doneAt and e.doneAt - e.at <= SWIFT_SECONDS then st.n.swift = st.n.swift + 1 end
end

-- What one settled row of the ledger is worth, once nothing can refuse it. A
-- favour returned; a request answered; or a stranger buffed unprompted, which
-- a buff they asked for is not and a resurrection is not either. Answers
-- whether the row stood.
local function CountRow(st, e, now)
	if e.kind == "received" then
		-- Still returned: a refusal puts the row back to owed.
		if e.state ~= "returned" then return false end
		CountReturn(st, e, now)
		return true
	end
	if e.asked then
		st.n.asked = st.n.asked + 1
	elseif e.to == "stranger" and not IsRes(e.spell) then
		Stranger(st, e.name, e.spell, e.at or now)
	end
	return true
end

-- The ledger's counts as a milestone may read them. The ledger counts a favour
-- returned when the cast is sent and takes it back on a refusal; here it
-- counts once the refusal can no longer come, so the returns still waiting are
-- left out.
local function Sum()
	local sum = Ledger.Summary()
	local held = 0
	for _, w in ipairs(waiting) do
		if w.entry.kind == "received" and w.entry.state == "returned" then held = held + 1 end
	end
	sum.totals.returned = math.max(0, (sum.totals.returned or 0) - held)
	return sum
end

---------------------------------------------------------------------------
-- toasts
---------------------------------------------------------------------------

local queue = {}
local toast, driver, lastShown

local GLOW = "Interface\\AddOns\\Manners\\Textures\\Glow"
local GLINT = "Interface\\AddOns\\Manners\\Textures\\Glint"
local TOAST_WIDTH, TOAST_HEIGHT = 300, 72
-- Where a toast may sit, the first that is clear of the prompt: high in the
-- middle, then nearer the centre, then low.
local SPOTS = { { "TOP", 0, -150 }, { "CENTER", 0, 170 }, { "BOTTOM", 0, 250 } }
local GOLD = { 1.00, 0.82, 0.30 }

local StepAside -- below

local function ToastUpdate(self, elapsed)
	-- Never in a fight: one that starts under a toast takes it away.
	if InCombatLockdown() then
		self:Hide()
		return
	end
	self.age = self.age + (tonumber(elapsed) or 0)
	local age = self.age
	-- Never over the prompt, which may come up, or be dragged, under a toast
	-- already showing: looked at a few times a second while it shows.
	if age >= (self.lookAt or 0) then
		self.lookAt = age + TOAST_LOOK
		StepAside(self)
	end
	if age < TOAST_IN then
		self:SetAlpha(age / TOAST_IN)
	elseif age < TOAST_IN + TOAST_HOLD then
		self:SetAlpha(1)
	elseif age < TOAST_IN + TOAST_HOLD + TOAST_OUT then
		self:SetAlpha(1 - (age - TOAST_IN - TOAST_HOLD) / TOAST_OUT)
	else
		self:Hide()
		return
	end
	-- The light behind the icon flares and settles; a glint crosses the plate
	-- once. Both hidden when done, never left at no alpha (Ledger.lua's rows).
	local flare = 1 - age / 1.8
	self.glow:SetShown(flare > 0)
	if flare > 0 then self.glow:SetAlpha(flare) end
	local sweep = (age - 0.25) / 0.9
	local crossing = sweep > 0 and sweep < 1
	self.glint:SetShown(crossing)
	if crossing then
		self.glint:ClearAllPoints()
		self.glint:SetPoint("LEFT", self, "LEFT", 2 + (TOAST_WIDTH - 100) * sweep, 0)
		self.glint:SetAlpha(0.55 * (1 - math.abs(sweep * 2 - 1)))
	end
end

local function ToastClicked(self)
	self:Hide()
end

-- The toast: drawn from the one solid texture the ledger is, and Manners' own
-- light, so no art a client might lack. A dark plate in a gilt rim, the icon
-- in a gilt frame on the left, a small heading, the name and one line.
local function BuildToast()
	local f = CreateFrame("Button", "MannersMilestoneToast", UIParent)
	f:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()

	local shadow = K.Solid(f, "BACKGROUND", -8)
	shadow:SetPoint("TOPLEFT", -5, 5)
	shadow:SetPoint("BOTTOMRIGHT", 5, -5)
	shadow:SetVertexColor(0, 0, 0, 0.28)
	local rim = K.Solid(f, "BACKGROUND", -7)
	rim:SetAllPoints()
	rim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
	local body = K.Solid(f, "BACKGROUND", -6)
	body:SetPoint("TOPLEFT", 2, -2)
	body:SetPoint("BOTTOMRIGHT", -2, 2)
	body:SetVertexColor(0.07, 0.05, 0.03, 1)
	local inner = K.Solid(f, "BACKGROUND", -5)
	inner:SetPoint("TOPLEFT", 4, -4)
	inner:SetPoint("BOTTOMRIGHT", -4, 4)
	inner:SetVertexColor(0.16, 0.11, 0.05, 1)
	-- A band of warmer light across the top, where the heading sits.
	local band = K.Solid(f, "BACKGROUND", -4)
	band:SetPoint("TOPLEFT", 4, -4)
	band:SetPoint("TOPRIGHT", -4, -4)
	band:SetHeight(18)
	band:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.13)
	local hair = K.Solid(f, "BORDER")
	hair:SetPoint("TOPLEFT", 62, -22)
	hair:SetPoint("TOPRIGHT", -10, -22)
	hair:SetHeight(1)
	hair:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.45)

	f.glow = f:CreateTexture(nil, "BORDER", nil, 1)
	f.glow:SetTexture(GLOW)
	f.glow:SetBlendMode("ADD")
	f.glow:SetSize(150, 150)
	f.glow:SetPoint("CENTER", f, "LEFT", 34, 0)
	f.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	f.glow:Hide()

	local iconRim = K.Solid(f, "ARTWORK")
	iconRim:SetSize(50, 50)
	iconRim:SetPoint("LEFT", f, "LEFT", 9, 0)
	iconRim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	local iconBack = K.Solid(f, "ARTWORK", 1)
	iconBack:SetSize(46, 46)
	iconBack:SetPoint("CENTER", iconRim, "CENTER")
	iconBack:SetVertexColor(0, 0, 0, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.icon:SetSize(44, 44)
	f.icon:SetPoint("CENTER", iconRim, "CENTER")

	f.heading = K.Text(f, 10, GOLD)
	f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 68, -8)
	f.heading:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
	f.name = K.Text(f, 15, { 1, 0.96, 0.84 })
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 68, -27)
	f.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -27)
	f.line = K.Text(f, 10, K.INK_SOFT)
	f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 68, -45)
	f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -45)
	K.Wrap(f.line, 2)

	f.glint = f:CreateTexture(nil, "OVERLAY", nil, 2)
	f.glint:SetTexture(GLINT)
	f.glint:SetBlendMode("ADD")
	f.glint:SetSize(96, TOAST_HEIGHT - 8)
	f.glint:Hide()

	f:SetScript("OnUpdate", ToastUpdate)
	f:SetScript("OnClick", ToastClicked)
	return f
end

-- Whether two frames share any of the screen. Asked when a toast is placed
-- and a few times a second while it shows (StepAside), out of a fight,
-- through pcall: a prompt that will not say where it is leaves the toast at
-- its first spot, which is nowhere near the prompt's own.
local function Covers(a, b)
	local ok, over = pcall(function()
		local sa, sb = a:GetEffectiveScale(), b:GetEffectiveScale()
		local al, ar, at, ab = a:GetLeft() * sa, a:GetRight() * sa, a:GetTop() * sa, a:GetBottom() * sa
		local bl, br, bt, bb = b:GetLeft() * sb, b:GetRight() * sb, b:GetTop() * sb, b:GetBottom() * sb
		return al < br and bl < ar and ab < bt and bb < at
	end)
	return ok and over == true
end

-- Never over the prompt: the first spot clear of it.
local function PlaceToast(f)
	local P = ns.Prompt
	local prompt = (P and P.GetButton and P:GetButton()) or _G.MannersPrompt
	local up = prompt and prompt.IsShown and prompt:IsShown()
	for i, spot in ipairs(SPOTS) do
		f:ClearAllPoints()
		f:SetPoint(spot[1], UIParent, spot[1], spot[2], spot[3])
		f.spot = i
		if not up or not Covers(f, prompt) then return end
	end
end

-- A toast on screen that the prompt has come up under moves to the first
-- spot clear of it; one that is clear stays where it is.
function StepAside(f)
	local P = ns.Prompt
	local prompt = (P and P.GetButton and P:GetButton()) or _G.MannersPrompt
	if prompt and prompt.IsShown and prompt:IsShown() and Covers(f, prompt) then PlaceToast(f) end
end

local function PlaySoundFor()
	if not Setting("sound") or type(_G.PlaySound) ~= "function" then return end
	local flavour = ns.Flavour and ns.Flavour.flavour
	pcall(_G.PlaySound, SOUND[flavour] or SOUND_ELSE)
end

local function ShowToast(item, now)
	if not toast then toast = BuildToast() end
	toast.heading:SetText(item.heading)
	toast.name:SetText(item.name)
	toast.line:SetText(item.line or "")
	toast.icon:SetTexture(item.icon or 134400)
	if type(item.icon) == "number" then toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else toast.icon:SetTexCoord(0, 1, 0, 1) end
	toast.item = item
	toast.age = 0
	toast.lookAt = TOAST_LOOK
	toast:SetAlpha(0)
	toast.glint:Hide()
	toast.glow:Hide()
	PlaceToast(toast)
	toast:Show()
	lastShown = now
	PlaySoundFor()
end

-- Why the next toast is not on screen yet, or nil: the one showing, a fight,
-- the minute kept between two.
local function Held(now)
	if toast and toast:IsShown() then return "showing" end
	if InCombatLockdown() then return "fight" end
	if lastShown and now - lastShown < TOAST_GAP then return "minute" end
	return nil
end

-- Show the next toast if nothing holds it. Called when one is queued and then
-- a few times a second by a frame that is shown only while one waits.
function M.Pump()
	if #queue > 0 and not (On() and Setting("toast")) then
		for i = #queue, 1, -1 do queue[i] = nil end
	end
	if #queue == 0 then
		if driver then driver:Hide() end
		return
	end
	local now = GetTime()
	if Held(now) then return end
	ShowToast(table.remove(queue, 1), now)
	if #queue == 0 and driver then driver:Hide() end
end

local function DriverUpdate(self, elapsed)
	self.wait = (self.wait or 0) + (tonumber(elapsed) or 0)
	if self.wait < 0.25 then return end
	self.wait = 0
	ns.Guard("milestones", M.Pump)
end

local function Toast(item)
	-- More than a few waiting would be a parade a quarter of an hour long:
	-- the rest have had their line in chat, and are on the tab.
	if #queue >= TOAST_QUEUE then return end
	queue[#queue + 1] = item
	M.Pump()
	if #queue > 0 then
		if not driver then
			driver = CreateFrame("Frame", nil, UIParent)
			driver:SetScript("OnUpdate", DriverUpdate)
		end
		driver:Show()
	end
end

-- For the scenarios and the renderer: the toast's frame, and what waits.
function M.ToastFrame() return toast end
function M.Waiting() return #queue end

---------------------------------------------------------------------------
-- earning
---------------------------------------------------------------------------

-- Whether this class has no buff for anybody else on this client (Buffs.lua):
-- nothing it can press writes the ledger's rows, which every milestone
-- without a `feature` of its own is read from.
local function NothingToGive()
	local class = ns.caps and ns.caps.class
	local without = ns.CLASSES_WITHOUT_BUFFS
	return class ~= nil and type(without) == "table" and without[class] == true
end

local function Available(def, st)
	if st.earned[def.id] then return true end
	if not def.feature and NothingToGive() then return false end
	if not def.feature then return true end
	local ok, has = pcall(def.feature)
	return ok and has == true
end

-- Every milestone the counts now reach and that is not marked yet. `quiet`
-- marks them with no toast and no line. Answers how many were new.
local function Evaluate(st, quiet)
	local now = K.Wall()
	if not now then return 0 end
	local sum = Sum()
	local new = 0
	for _, def in ipairs(LIST) do
		if not st.earned[def.id] and Available(def, st) and (def.value(st, sum, now) or 0) >= def.goal then
			st.earned[def.id] = quiet and -now or now
			new = new + 1
			if not quiet then
				if ns.addon and ns.addon.Print then ns.addon:Print(TEXT.EARNED:format(def.name, def.desc)) end
				Toast({ heading = TEXT.HEAD_MILESTONE, name = def.name, line = def.desc, icon = def.icon, id = def.id })
			end
		end
	end
	-- The one that completed them: the hall of fame says where the code is.
	if new > 0 and not quiet and ns.Hall then ns.Hall.Announce() end
	return new
end

-- The ledger's past, read once: what its rows and counts already show.
local function Seed(st)
	local now = K.Wall()
	if not now then return false end
	local sum = Ledger.Summary()
	local list = Ledger.Entries("all")
	local days = {}
	-- Of the ledger's strangers, the rows that were no buff given unprompted:
	-- one they asked for, or a resurrection.
	local other = 0
	for i = #list, 1, -1 do
		local e = list[i]
		if e.kind == "received" and e.state == "returned" then
			local day = DayKey(e.doneAt or e.at)
			if not days[e.name .. "\0" .. day] then
				days[e.name .. "\0" .. day] = true
				MetAgain(st, e.name, day)
			end
			if day == DayKey(now) then ThankedToday(st, e.name, day) end
			if e.class then st.classes[e.class] = true end
			if e.doneAt and e.doneAt - e.at <= SWIFT_SECONDS then st.n.swift = math.max(st.n.swift, 1) end
		elseif e.kind == "given" then
			if e.asked then st.n.asked = math.max(st.n.asked, 1) end
			if e.to == "stranger" and (e.asked or IsRes(e.spell)) then other = other + 1 end
		end
	end
	st.n.strangers = math.max(st.n.strangers, Count(Count(sum.totals.strangers) - other))
	st.seeded = true
	return true
end

-- Milestones meet this character's ledger: the first time, its past is read
-- and what it had already earned is marked without a toast, with one line.
local function Begin(st)
	if st.seeded then return end
	if not Seed(st) then return end
	local had = Evaluate(st, true)
	if had > 0 and ns.addon and ns.addon.Print then
		ns.addon:Print(had == 1 and TEXT.SEEDED_ONE or TEXT.SEEDED_MANY:format(had))
	end
end

local dueTimer = false

-- A settle is no longer remembered for the next session: counted or refused.
local function Undue(st, d)
	for i = #st.due, 1, -1 do
		if st.due[i] == d then table.remove(st.due, i) end
	end
end

-- Nothing waits: the switch is off.
local function Forget()
	for i = #waiting, 1, -1 do waiting[i] = nil end
	local st = Store()
	if st then st.due = {} end
end

local function Due()
	dueTimer = false
	local st = On() and Store()
	if not st then return Forget() end
	local clock, now = GetTime(), K.Wall()
	local wait = Ledger.PROMOTE_SECONDS or 3
	local left
	local i = 1
	while i <= #waiting do
		local w = waiting[i]
		if clock - w.clock >= wait - 0.01 then
			table.remove(waiting, i)
			Undue(st, w.due)
			local e = w.entry
			if now and CountRow(st, e, now) and w.size then
				if e.kind == "received" then
					if not w.grouped then Sat(st, w.key or e.gave, w.names, w.size, w.clock) end
				elseif e.to == "group" and not IsRes(e.spell) then
					Sat(st, w.key or e.spell, w.names, w.size, w.clock)
				end
			end
		else
			left = math.min(left or wait, wait - (clock - w.clock))
			i = i + 1
		end
	end
	Evaluate(st, false)
	if Ledger.Scroll then Ledger.Scroll(0) end
	if left and C_Timer and C_Timer.After then
		dueTimer = true
		C_Timer.After(left, function() ns.Guard("milestones", Due) end)
	end
end

-- The settles a reload, a logout or a disconnect cut off inside their wait:
-- the ledger has them on disk, and no refusal can come for them now. Each is
-- counted from its row, if the row still stands, and what that earns is said
-- as it would have been.
local function Resume(st)
	local due = st.due
	if #due == 0 or #waiting > 0 then return end
	st.due = {}
	local now = K.Wall()
	if not now then return end
	local list, used = Ledger.Entries("all"), {}
	for _, d in ipairs(due) do
		for _, e in ipairs(list) do
			local at = e.kind == "received" and e.doneAt or e.at
			if not used[e] and e.kind == d.kind and e.name == d.name and at == d.at then
				used[e] = true
				CountRow(st, e, now)
				break
			end
		end
	end
	Evaluate(st, false)
end

---------------------------------------------------------------------------
-- what the ledger and the other features tell it
---------------------------------------------------------------------------

-- At login, after the ledger has its rows.
function M.Load()
	local st = Store()
	if not st then return end
	if not On() then
		st.due = {}
		return
	end
	Begin(st)
	Resume(st)
end

-- A cast settled: `entry` is the ledger's row for it, a favour returned or a
-- buff given. Counted once the refusal can no longer come.
function M.Settled(entry, pending)
	if type(entry) ~= "table" or not On() then return end
	local st = Store()
	if not st then return end
	Begin(st)
	local w = { entry = entry, clock = GetTime(), names = { entry.name } }
	-- Remembered on disk until it is counted or refused (Resume).
	w.due = { kind = entry.kind, name = entry.name, at = entry.kind == "received" and entry.doneAt or entry.at }
	if #st.due < MAX_DUE then st.due[#st.due + 1] = w.due end
	-- Which buff it was, for the sitting: one key for its every spell.
	if type(pending) == "table" and type(pending.buffKey) == "string" then w.key = pending.buffKey end
	-- In a raid, for "everybody in your raid": how big it is now, and whether
	-- this was one of the people a group cast covered, who are counted with it.
	-- The one the cast was aimed at is not such a one (Clicks.lua marks the
	-- others `member`): owed a favour, their row is the only one that names
	-- them, so it counts them and everybody the cast reached with them.
	if type(pending) == "table" and pending.inGroup == true and plain(_G.IsInRaid and _G.IsInRaid()) == true then
		local size = plain(_G.GetNumGroupMembers and _G.GetNumGroupMembers())
		if type(size) == "number" then w.size = size end
		local group = type(pending.group) == "table" and pending.group or nil
		w.grouped = group ~= nil and (pending.member == true or entry.kind ~= "received")
		-- Everybody else a group cast reached, by name: a member is a name
		-- (GroupBuffs.lua) or a table that holds one.
		local members = group and group.members
		for _, member in ipairs(type(members) == "table" and members or {}) do
			local name = type(member) == "table" and member.name or member
			if type(name) == "string" then w.names[#w.names + 1] = name end
		end
		-- And everybody else a cast with no group version reached: on Mists
		-- and retail one cast on a member lands on the whole raid, and a shout
		-- on everybody who hears it (Prompt/Press.lua files both with the
		-- press, Clicks.lua settles them with it).
		for _, list in ipairs({ pending.wideMembers or false, pending.selfCast and pending.shoutMembers or false }) do
			for _, name in ipairs(type(list) == "table" and list or {}) do
				if type(name) == "string" then w.names[#w.names + 1] = name end
			end
		end
	end
	waiting[#waiting + 1] = w
	if not (C_Timer and C_Timer.After) then
		w.clock = w.clock - (Ledger.PROMOTE_SECONDS or 3)
		return Due()
	end
	if not dueTimer then
		dueTimer = true
		C_Timer.After(Ledger.PROMOTE_SECONDS or 3, function() ns.Guard("milestones", Due) end)
	end
end

-- The ledger is about to drop a row, by its Clear or its trim. A favour of
-- the last week is remembered for the week without a debt, which is read from
-- the rows: one returned as returned, one left unreturned as that. Whatever
-- the week does not score (WeekKept) is not kept.
function M.Dropped(e)
	if type(e) ~= "table" or e.kind ~= "received" or type(e.at) ~= "number" or not On() then return end
	local st, now = Store(), K.Wall()
	if not st or not now or e.at < now - WEEK_SECONDS then return end
	if e.state == "back" or e.why == "useless" or e.why == "covered" then return end
	local week = st.week
	if e.state ~= "returned" then
		if not week.broke or e.at > week.broke then week.broke = e.at end
		return
	end
	local kept = week.kept
	for i = #kept, 1, -1 do
		if kept[i] < now - WEEK_SECONDS then table.remove(kept, i) end
	end
	if #kept >= MAX_KEPT then table.remove(kept, 1) end
	kept[#kept + 1] = e.at
end

-- The server refused the cast after all: its row counts for nothing.
function M.Refused(entry)
	local st = Store()
	for i = #waiting, 1, -1 do
		if waiting[i].entry == entry then
			if st then Undue(st, waiting[i].due) end
			table.remove(waiting, i)
		end
	end
end

-- Another feature's good turn, told when its cast is known to have landed:
-- "res", "cure" or "courtesy".
function M.Note(kind)
	if not NOTES[kind] or not On() then return end
	local st = Store()
	if not st then return end
	Begin(st)
	st.n[kind] = st.n[kind] + 1
	Evaluate(st, false)
	if Ledger.Scroll then Ledger.Scroll(0) end
end

-- A new title (Ledger.lua, Announce), which has had its line in chat.
function M.Ranked(title)
	if type(title) ~= "table" or not On() then return end
	Toast({ heading = TEXT.HEAD_TITLE, name = title.name, line = title.flavour, icon = K.LOGO })
end

-- The switch was turned, by hand or by the profile changing under it (Core.lua,
-- RefreshConfig: the switch is the profile's, the milestones the character's).
-- On: the ledger's past is read if it never was, and whatever was passed while
-- it was off is marked without a toast, so nothing is to be had by turning it.
-- Off: nothing waits, nothing shows.
function M.Switched()
	if On() then
		local st = Store()
		if st then
			if st.seeded then Evaluate(st, true) else Begin(st) end
		end
	else
		Forget()
		for i = #queue, 1, -1 do queue[i] = nil end
		if toast then toast:Hide() end
	end
	if Ledger.Scroll then Ledger.Scroll(0) end
end

-- How many are earned, of how many this character can earn.
function M.Tally()
	local st = Store()
	local earned, of = 0, 0
	if not st then return 0, 0 end
	for _, def in ipairs(LIST) do
		if Available(def, st) then
			of = of + 1
			if st.earned[def.id] then earned = earned + 1 end
		end
	end
	return earned, of
end

-- When the latest of them was earned, on the wall clock (one marked as passed
-- before milestones were kept counts from when it was marked); nil with none.
-- The hall of fame's code carries its day (Hall.lua).
function M.LastEarned()
	local st = Store()
	local last
	for _, at in pairs(st and st.earned or {}) do
		local when = math.abs(at)
		if not last or when > last then last = when end
	end
	return last
end

-- /manners debug and the check-up: whether it is on, how many are earned, and
-- what holds a toast back.
function M.Lines()
	if not On() then return { TEXT.LINE_OFF } end
	local out = { TEXT.LINE_COUNT:format(M.Tally()) }
	if not Setting("toast") then
		out[#out + 1] = TEXT.LINE_TOAST_OFF
	elseif #queue > 0 then
		local held = Held(GetTime())
		out[#out + 1] = (held == "fight" and TEXT.LINE_HELD_FIGHT or held == "minute" and TEXT.LINE_HELD_MINUTE
			or TEXT.LINE_HELD_SHOWING):format(#queue)
	end
	return out
end

---------------------------------------------------------------------------
-- the ledger window's tab
---------------------------------------------------------------------------

local rowById = {}

-- The tab is there while milestones are on. Answers this table while it is
-- the tab on show, for the window to list and paint through.
function M.Page(window, filter)
	-- Nor for a character with none to earn and none earned.
	local on = On() and select(2, M.Tally()) > 0
	for _, tab in ipairs(window and window.tabs or {}) do
		if tab.key == "milestones" then tab:SetShown(on) end
	end
	return on and filter == "milestones" and M or nil
end

-- The rows: earned first, the newest on top; then what is under way, the
-- nearest first; then the hidden ones. The same table for a milestone each
-- time, so the window's flash plays only when the top one really changes.
function M.Rows()
	local st = Store()
	local out = {}
	if not st then return out end
	Begin(st)
	local now, sum = K.Wall(), Sum()
	for order, def in ipairs(LIST) do
		if Available(def, st) then
			local row = rowById[def.id]
			if not row then
				row = { milestone = true, def = def, id = def.id }
				rowById[def.id] = row
			end
			row.order = order
			row.earnedAt = st.earned[def.id]
			row.concealed = def.hidden == true and not row.earnedAt
			row.value = 0
			if not row.earnedAt and not row.concealed then
				row.value = math.min(def.goal, def.value(st, sum, now) or 0)
			end
			out[#out + 1] = row
		end
	end
	table.sort(out, function(a, b)
		local ea, eb = a.earnedAt, b.earnedAt
		if (ea ~= nil) ~= (eb ~= nil) then return ea ~= nil end
		if ea and math.abs(ea) ~= math.abs(eb) then return math.abs(ea) > math.abs(eb) end
		if a.concealed ~= b.concealed then return not a.concealed end
		local sa, sb = a.value / a.def.goal, b.value / b.def.goal
		if not ea and sa ~= sb then return sa > sb end
		return a.order < b.order
	end)
	return out
end

-- The one line for the chat box: plain text, no colour and no link, so it is
-- the same in every channel. Only put in the box; the player sends it.
function M.LinkText(def)
	local text = TEXT.LINK_LINE:format(def.name, def.desc):gsub("|", "")
	return text:sub(1, 255)
end

function M.Link(def)
	local text = M.LinkText(def)
	local open = (_G.ChatFrameUtil and _G.ChatFrameUtil.OpenChat) or _G.ChatFrame_OpenChat
	if type(open) == "function" then pcall(open, text) end
	return text
end

local function LinkClicked(self)
	local m = self:GetParent().entry
	if m and m.milestone and m.earnedAt then M.Link(m.def) end
end

-- How wide the link button is: a glyph, not its words, which in French or
-- Portuguese took 130 of the row's 328 and left the line beside it a dozen
-- letters.
local LINK_WIDTH = 22

-- A speech bubble drawn from the one solid texture: a body, a tail, three dots.
local function LinkGlyph(b)
	local ink = K.INK
	local body = K.Solid(b, "ARTWORK")
	body:SetSize(12, 8)
	body:SetPoint("CENTER", b, "CENTER", 0, 1)
	body:SetVertexColor(ink[1], ink[2], ink[3], 0.9)
	local tail = K.Solid(b, "ARTWORK")
	tail:SetSize(3, 2)
	tail:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 2, 0)
	tail:SetVertexColor(ink[1], ink[2], ink[3], 0.9)
	for i = 0, 2 do
		local dot = K.Solid(b, "ARTWORK", 1)
		dot:SetSize(2, 2)
		dot:SetPoint("LEFT", body, "LEFT", 2 + i * 3, 0)
		dot:SetVertexColor(0, 0, 0, 0.9)
	end
end

-- A ledger row painted as a milestone: the icon, the name over a badge and
-- the line, the date on the right, and on an earned one the link button.
function M.Paint(row, m)
	local def = m.def
	if not row.link then
		-- A small button, the same in every language: its words are in its
		-- tooltip, and the row's one line keeps the width they would take.
		row.link = K.FlatButton(row, "", LINK_WIDTH, 14, 0.1)
		LinkGlyph(row.link)
		row.link:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 2)
		row.link.tip = "|cffffd100" .. TEXT.LINK .. "|r\n" .. TEXT.LINK_TIP
		row.link:SetScript("OnClick", LinkClicked)
	end
	row.entry = m
	local earned = m.earnedAt ~= nil
	local colour = earned and K.COLOUR.returned or m.concealed and K.COLOUR.letgo or K.COLOUR.owed
	row.icon:SetTexture(m.concealed and 134400 or def.icon)
	if row.icon.SetDesaturated then row.icon:SetDesaturated(not earned) end
	row.name:SetText(m.concealed and TEXT.HIDDEN_NAME or def.name)
	local ink = earned and K.RANK_INK or K.INK_SOFT
	row.name:SetTextColor(ink[1], ink[2], ink[3])
	local when = ""
	if earned then
		when = m.earnedAt < 0 and TEXT.BEFORE:format(DateText(-m.earnedAt)) or DateText(m.earnedAt)
	end
	row.when:SetText(when)
	local badge = earned and TEXT.BADGE_EARNED
		or m.concealed and TEXT.BADGE_HIDDEN
		or def.goal > 1 and TEXT.BADGE_PROGRESS:format(m.value, def.goal)
		or TEXT.BADGE_NOT_YET
	row.badge:SetText(badge)
	row.badge:SetTextColor(colour[1], colour[2], colour[3])
	local plate = math.min(120, math.ceil(K.TextWidth(row.badge)) + 10)
	row.badgePlate:SetWidth(plate)
	row.badge:SetWidth(plate - 6)
	row.badgePlate:SetVertexColor(colour[1], colour[2], colour[3], 0.16)
	row.detail:SetText(m.concealed and TEXT.HIDDEN_DESC or def.desc)
	-- The line stops short of the link button on an earned row.
	row.link:SetShown(earned)
	row.detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", earned and -(row.link:GetWidth() + 12) or -8, 4)
	row.stripe:SetVertexColor(colour[1], colour[2], colour[3], 0.9)
	row.flash:SetVertexColor(colour[1], colour[2], colour[3], 1)
	row:SetAlpha(earned and 1 or 0.8)
	row:Show()
end

-- The row handed back to the ledger's own painting, as it was built.
function M.Unpaint(row)
	row.link:Hide()
	row.detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)
	if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
	row.name:SetTextColor(K.INK[1], K.INK[2], K.INK[3])
end

function M.Tooltip(row, m)
	local def = m.def
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	if m.concealed then
		GameTooltip:AddLine(TEXT.HIDDEN_NAME, K.INK_SOFT[1], K.INK_SOFT[2], K.INK_SOFT[3])
		GameTooltip:AddLine(TEXT.HIDDEN_DESC, 1, 1, 1, true)
		GameTooltip:Show()
		return
	end
	GameTooltip:AddLine(def.name, K.RANK_INK[1], K.RANK_INK[2], K.RANK_INK[3])
	GameTooltip:AddLine(def.desc, 1, 1, 1, true)
	if def.note then GameTooltip:AddLine(def.note, 0.7, 0.7, 0.7, true) end
	local c = K.COLOUR.returned
	if m.earnedAt and m.earnedAt < 0 then
		GameTooltip:AddLine(TEXT.TIP_BEFORE:format(DateText(-m.earnedAt)), c[1], c[2], c[3], true)
	elseif m.earnedAt then
		GameTooltip:AddLine(TEXT.TIP_EARNED:format(DateText(m.earnedAt)), c[1], c[2], c[3], true)
	elseif def.goal > 1 then
		c = K.COLOUR.owed
		GameTooltip:AddLine(TEXT.TIP_PROGRESS:format(m.value, def.goal), c[1], c[2], c[3], true)
	end
	GameTooltip:Show()
end
