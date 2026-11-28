-- Manners: Achievements -- quiet rewards for good manners, shown in full on the
-- module's own options page (no separate window, no ledger tab).
--
-- Every achievement reads one count ("metric") kept per character and class,
-- and has its own goals: one goal for a single medal, three for bronze, silver
-- and gold. Counting is capped once per metric, person and day, so holding the
-- prompt at a nameplate can never manufacture progress. The page draws the
-- summary (rank, points, medals), what was earned last, every achievement as a
-- row that can be filtered, sorted and narrowed to one kind, the counts behind
-- them, and the notification settings.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("achievements"), "Manners module API is missing")
local L = ns.L
local A = {}
local initialized = false
local recent = {}
local toast
local toastEpoch = 0
local version = 0
local ShowToast

local function Active()
	return api:ModuleActive("achievements") == true
end

api:RegisterModuleLifecycle("achievements", function()
	toastEpoch = toastEpoch + 1
	if toast then toast:Hide() end
end, function() end)

-- The saved data's shape: 2 reads goals per achievement (1 had 10/100/1000 for all).
local DATA_VERSION = 2
local MEDALS = {
	{ name = L["Bronze"], colour = "cd8a4a", points = 10 },
	{ name = L["Silver"], colour = "c8ccd4", points = 25 },
	{ name = L["Gold"], colour = "ffd100", points = 50 },
}
-- A single-goal achievement is worth this; a hidden one this more.
local SINGLE_POINTS, HIDDEN_BONUS = 15, 10
local ICONS = "Interface\\Icons\\"
local LOCKED_ICON = ICONS .. "INV_Misc_QuestionMark"

local THEMES = {
	{ id = "gratitude", name = L["Gratitude"], colour = "f5ba59" },
	{ id = "generosity", name = L["Generosity"], colour = "59bfeb" },
	{ id = "fellowship", name = L["Fellowship"], colour = "80d18c" },
	{ id = "courtesy", name = L["Courtesy"], colour = "c794eb" },
	{ id = "devotion", name = L["Devotion"], colour = "eb8f8f" },
}
local THEME = {}
for i, theme in ipairs(THEMES) do theme.order = i THEME[theme.id] = theme end

-- The ranks the points earn, low to high.
local RANKS = {
	{ at = 0, name = L["Newcomer"] },
	{ at = 50, name = L["Polite Stranger"] },
	{ at = 150, name = L["Courteous Adventurer"] },
	{ at = 350, name = L["Gracious Companion"] },
	{ at = 700, name = L["Pillar of Good Manners"] },
	{ at = 1200, name = L["Paragon of Courtesy"] },
}

local DEFS = {
	-- Gratitude: returning what others gave you.
	{ id = "first", theme = "gratitude", metric = "returns", goals = { 1 }, icon = "Spell_Holy_HolyBolt",
		name = L["Much Obliged"], desc = L["Return your first favour."] },
	{ id = "returns", theme = "gratitude", metric = "returns", goals = { 10, 100, 500 }, icon = "Spell_Holy_Renew",
		name = L["Returning the Favour"], desc = L["Favours you returned."] },
	{ id = "swift", theme = "gratitude", metric = "quick", goals = { 1, 25, 100 }, icon = "Spell_Holy_SealOfWisdom",
		name = L["Quick to Thank"], desc = L["Favours returned within ten seconds of receiving them."] },
	{ id = "day10", theme = "gratitude", metric = "differentDaily", goals = { 5, 10, 20 }, icon = "Spell_Holy_PrayerOfHealing02",
		name = L["Thank You, Everyone"], desc = L["Different people you returned a favour to in one day."] },
	{ id = "regular", theme = "gratitude", metric = "returnDays", goals = { 3, 10, 30 }, icon = "Spell_Holy_MagicalSentry",
		name = L["Old Acquaintance"], desc = L["Days you returned a favour to the same person."] },
	{ id = "classes", theme = "gratitude", metric = "classes", goals = { 3, 5, 8 }, icon = "Spell_Holy_WordFortitude",
		name = L["All Walks of Life"], desc = L["Classes you returned a favour to."] },
	{ id = "week", theme = "gratitude", metric = "cleanDays", goals = { 1, 7, 30 }, icon = "INV_Misc_Note_01",
		name = L["A Clean Slate"], desc = L["Days you thanked people and let no favour go unreturned."] },

	-- Generosity: giving without being asked.
	{ id = "kind", theme = "generosity", metric = "strangers", goals = { 1 }, icon = "Spell_Holy_Heal",
		name = L["A Kind Stranger"], desc = L["Buff a passer-by who did not ask."] },
	{ id = "strangers", theme = "generosity", metric = "strangers", goals = { 50, 250, 1000 }, icon = "Spell_Holy_GreaterHeal",
		name = L["The Kindness of Strangers"], desc = L["Passers-by you buffed unprompted."] },
	{ id = "given", theme = "generosity", metric = "given", goals = { 100, 1000, 5000 }, icon = "Spell_Holy_PowerWordShield",
		name = L["Open Hand"], desc = L["Buffs you gave to other players."] },
	{ id = "people", theme = "generosity", metric = "people", goals = { 25, 100, 500 }, icon = "Spell_Holy_HolySmite",
		name = L["Friend to All"], desc = L["Different people you gave something to."] },
	{ id = "gifts", theme = "generosity", metric = "spells", goals = { 2, 4, 6 }, icon = "Spell_Holy_ArcaneIntellect",
		name = L["Varied Gifts"], desc = L["Different spells you gave to other players."] },
	{ id = "threedays", theme = "generosity", metric = "strangerDays", goals = { 3 }, hidden = true, icon = "Spell_Holy_Restoration",
		name = L["A Familiar Kindness"], desc = L["Buff the same passer-by on three different days."] },

	-- Fellowship: looking after the people beside you.
	{ id = "raid", theme = "fellowship", metric = "groups", goals = { 25, 250, 1000 }, icon = "Spell_Holy_PrayerOfFortitude",
		name = L["Nobody Left Out"], desc = L["Party and raid members you buffed."] },
	{ id = "res", theme = "fellowship", metric = "res", goals = { 1, 25, 100 }, icon = "Spell_Holy_Resurrection",
		name = L["Back on Your Feet"], desc = L["People you brought back to life through the prompt."] },
	{ id = "guardian", theme = "fellowship", metric = "rescues", goals = { 3 }, hidden = true, icon = "Spell_Holy_LayOnHands",
		name = L["Steady Hands"], desc = L["Resurrect the same person on three different days."] },
	{ id = "cure", theme = "fellowship", metric = "cures", goals = { 1, 25, 100 }, icon = "Spell_Holy_DispelMagic",
		name = L["A Clean Bill of Health"], desc = L["People you cured through the prompt."] },
	{ id = "liked", theme = "fellowship", metric = "givers", goals = { 10, 50, 200 }, icon = "Spell_Nature_Regeneration",
		name = L["Well Liked"], desc = L["Different people who buffed you."] },
	{ id = "company", theme = "fellowship", metric = "received", goals = { 25, 250, 1000 }, icon = "Spell_Nature_Rejuvenation",
		name = L["In Good Company"], desc = L["Buffs other players gave you."] },

	-- Courtesy: answering, serving and saying thank you.
	{ id = "asked", theme = "courtesy", metric = "asked", goals = { 1, 25, 100 }, icon = "INV_Misc_Note_02",
		name = L["You Only Had to Ask"], desc = L["Requests made in chat that you answered."] },
	{ id = "courtesy", theme = "courtesy", metric = "services", goals = { 1, 25, 100 }, icon = "Spell_Arcane_PortalStormWind",
		name = L["At Your Service"], desc = L["Conjures, portals, summons and other services given on request."] },
	{ id = "trades", theme = "courtesy", metric = "serviceKinds", goals = { 2, 4 }, icon = "INV_Misc_Bag_10",
		name = L["A Helping Hand"], desc = L["Different kinds of service you gave."] },
	{ id = "thanks", theme = "courtesy", metric = "thanks", goals = { 1, 50, 250 }, icon = "Spell_Holy_SealOfSalvation",
		name = L["The Polite Reply"], desc = L["People you thanked for a buff."] },
	{ id = "notes", theme = "courtesy", metric = "thankDays", goals = { 3, 14, 60 }, icon = "INV_Misc_Note_03",
		name = L["Thank-You Notes"], desc = L["Days you thanked somebody for a buff."] },
	{ id = "host", theme = "courtesy", metric = "servicePeople", goals = { 5, 25, 100 }, icon = "INV_Drink_04",
		name = L["Gracious Host"], desc = L["Different people you gave a service to."] },
	{ id = "grace", theme = "courtesy", metric = "refused", goals = { 1 }, hidden = true, icon = "Spell_Holy_SealOfSacrifice",
		name = L["No Hard Feelings"], desc = L["Somebody turned down your buff, and you let it go."] },

	-- Devotion: good manners kept up day after day.
	{ id = "daily", theme = "devotion", metric = "activeDays", goals = { 7, 30, 100 }, icon = "INV_Misc_PocketWatch_01",
		name = L["Daily Courtesy"], desc = L["Days you showed good manners."] },
	{ id = "streak", theme = "devotion", metric = "bestStreak", goals = { 3, 7, 30 }, icon = "Spell_Holy_Excorcism",
		name = L["Unbroken Courtesy"], desc = L["Days in a row you showed good manners."] },
	{ id = "early", theme = "devotion", metric = "early", goals = { 1 }, hidden = true, icon = "Spell_Holy_SurgeOfLight",
		name = L["Early Riser"], desc = L["Show good manners between five and eight in the morning."] },
	{ id = "late", theme = "devotion", metric = "late", goals = { 1 }, hidden = true, icon = "Spell_Nature_Sleep",
		name = L["Night Owl"], desc = L["Show good manners between midnight and four in the morning."] },
	{ id = "medals", theme = "devotion", metric = "medals", goals = { 10, 25, 50 }, icon = "INV_Misc_Coin_01",
		name = L["Well Mannered"], desc = L["Medals you earned in Manners achievements."] },
}
for i, def in ipairs(DEFS) do def.order = i end

local function Day(at)
	return date("%Y%m%d", at or time())
end

local function PlainClass()
	local class = api:Plain(select(2, UnitClass("player")))
	return type(class) == "string" and class or "?"
end

local function CharacterKey()
	local guid = type(UnitGUID) == "function" and api:Plain(UnitGUID("player")) or nil
	return (type(guid) == "string" and guid or "local") .. ":" .. PlainClass()
end

local SETTINGS = {
	filter = { all = true, earned = true, progress = true, locked = true },
	sort = { theme = true, closest = true, recent = true, name = true },
}

local function Database()
	if type(MannersAchievementsDB) ~= "table" then MannersAchievementsDB = {} end
	local db = MannersAchievementsDB
	db.characters = type(db.characters) == "table" and db.characters or {}
	local notification = db.notification
	if notification ~= "toast" and notification ~= "chat" then notification = "none" end
	db.notification = notification
	db.sound = db.sound == true
	if not SETTINGS.filter[db.filter] then db.filter = "all" end
	if not SETTINGS.sort[db.sort] then db.sort = "theme" end
	if db.theme ~= "all" and not THEME[db.theme] then db.theme = "all" end
	return db
end

local TABLES = { "metrics", "earned", "capped", "personDays", "strangerDays", "classes", "dirtyDays",
	"when", "people", "givers", "spells", "serviceKinds", "days", "servicePeople", "thankDays" }

local function Fresh()
	local st = { class = PlainClass(), seeded = false, version = DATA_VERSION }
	for _, name in ipairs(TABLES) do st[name] = {} end
	return st
end

local function Count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function Value(st, def)
	return st.metrics[def.metric] or 0
end

local function TierOf(def, progress)
	local tier = 0
	for i, goal in ipairs(def.goals) do
		if progress >= goal then tier = i end
	end
	return tier
end

-- The medal a tier is: a single goal has no bronze, silver or gold of its own.
local function MedalOf(def, tier)
	if tier < 1 then return nil end
	if #def.goals == 1 then return MEDALS[3] end
	return MEDALS[math.min(3, tier + (3 - #def.goals))]
end

local function PointsOf(def, tier)
	if tier < 1 then return 0 end
	if #def.goals == 1 then return SINGLE_POINTS + (def.hidden and HIDDEN_BONUS or 0) end
	local points = 0
	for i = 1, tier do points = points + MedalOf(def, i).points end
	return points
end

local Recheck

local function State()
	local db = Database()
	local key = CharacterKey()
	local st = db.characters[key]
	if type(st) ~= "table" then
		st = Fresh()
		db.characters[key] = st
	end
	for _, name in ipairs(TABLES) do
		if type(st[name]) ~= "table" then st[name] = {} end
	end
	-- Older saves counted the same metrics against 10/100/1000 for every
	-- achievement: the counts stand, the medals are worked out again.
	if st.version ~= DATA_VERSION then
		st.version = DATA_VERSION
		st.metrics.classes = Count(st.classes)
		for id in pairs(st.earned) do st.earned[id] = nil end
		Recheck(st, false)
	end
	return st
end

local function Bump()
	version = version + 1
	if ns.RefreshOptionsDisplay and Active() then api:Guard("achievements repaint", ns.RefreshOptionsDisplay) end
end

local function Notify(def, tier)
	local db = Database()
	if db.notification == "none" then return end
	local medal = MedalOf(def, tier)
	local line = L["%s reached %s: %s"]:format(def.name, medal and medal.name or "", def.desc)
	if db.notification == "chat" and ns and ns.addon then
		ns.addon:Print(line)
	elseif db.notification == "toast" then
		ShowToast(def, tier, line)
	end
	if db.sound and type(PlaySound) == "function" then
		pcall(PlaySound, 888)
	end
end

Recheck = function(st, announce)
	-- Twice: a medal earned on the first pass counts toward Well Mannered.
	for _ = 1, 2 do
		local medals = 0
		for _, def in ipairs(DEFS) do
			if def.metric ~= "medals" then medals = medals + (st.earned[def.id] or 0) end
		end
		st.metrics.medals = medals
		for _, def in ipairs(DEFS) do
			local tier = TierOf(def, Value(st, def))
			local before = st.earned[def.id] or 0
			if tier > before then
				st.earned[def.id] = tier
				st.when[def.id] = time()
				if announce then Notify(def, tier) end
			end
		end
	end
end

-- A day with good manners: the count of such days and the longest run of them.
local function Showed(st, at)
	at = at or time()
	local day = Day(at)
	if st.days[day] then return end
	st.days[day] = true
	st.metrics.activeDays = Count(st.days)
	local run, back, last = 1, 1, day
	-- Bounded, and stopped on a day that reads the same as the one after it.
	while back <= 400 do
		local before = Day(at - back * 86400)
		if before == last or not st.days[before] then break end
		run, back, last = run + 1, back + 1, before
	end
	st.metrics.streak = run
	st.metrics.bestStreak = math.max(st.metrics.bestStreak or 0, run)
	local hour = tonumber(date("%H", at)) or 12
	if hour >= 5 and hour < 8 then st.metrics.early = 1 end
	if hour < 4 then st.metrics.late = 1 end
end

-- At most one credit for a metric/person/day. This is the anti-spam wall:
-- holding a prompt at a nameplate can never manufacture progress.
local function Credit(metric, name, amount, announce, at)
	name = type(name) == "string" and name ~= "" and name or "?"
	local st = State()
	local day = Day(at)
	st.capped[day] = type(st.capped[day]) == "table" and st.capped[day] or {}
	local key = metric .. "\0" .. name
	if st.capped[day][key] then return false end
	st.capped[day][key] = true
	st.metrics[metric] = (st.metrics[metric] or 0) + (amount or 1)
	Showed(st, at)
	Recheck(st, announce ~= false)
	return true
end

-- A name into a set, with the set's size kept as a metric.
local function Collect(st, set, name, metric)
	if type(name) ~= "string" or name == "" or set[name] then return end
	set[name] = true
	st.metrics[metric] = Count(set)
end

local function DifferentDays(st, store, name, day, metric)
	if type(name) ~= "string" or name == "" then return end
	store[name] = type(store[name]) == "table" and store[name] or {}
	if not store[name][day] then
		store[name][day] = true
		st.metrics[metric] = math.max(st.metrics[metric] or 0, Count(store[name]))
	end
end

local function OnReceived(_, seen)
	if not Active() then return end
	if type(seen) ~= "table" or type(seen.name) ~= "string" then return end
	recent[seen.name] = GetTime()
	local st = State()
	st.dirtyDays[Day()] = nil
	Collect(st, st.givers, seen.name, "givers")
	Credit("received", seen.name, 1, true)
	Bump()
end

local function OnSettled(_, name, debt, pending, spellId)
	if not Active() then return end
	pending = type(pending) == "table" and pending or {}
	local st = State()
	local day = Day()
	if type(name) == "string" and not pending.res and not pending.cure then
		Collect(st, st.people, name, "people")
		local spell = api:Plain(spellId)
		if type(spell) == "number" then
			local nameFor = ns.SpellNameFor
			local spellName = type(nameFor) == "function" and api:Plain(nameFor(spell)) or nil
			Collect(st, st.spells, type(spellName) == "string" and spellName or tostring(spell), "spells")
		end
		Credit("given", name, 1, true)
	end
	if debt then
		if Credit("returns", name, 1, true) then
			DifferentDays(st, st.personDays, name, day, "returnDays")
			local heard = recent[name]
			if type(heard) == "number" and GetTime() - heard <= 10 then Credit("quick", name, 1, true) end
			if type(debt.class) == "string" then Collect(st, st.classes, debt.class, "classes") end
			local daily = 0
			for key in pairs(st.capped[day] or {}) do
				if key:sub(1, 8) == "returns\0" then daily = daily + 1 end
			end
			st.metrics.differentDaily = math.max(st.metrics.differentDaily or 0, daily)
		end
	elseif pending.reason == "asked" then
		Credit("asked", name, 1, true)
	elseif pending.cure then
		Credit("cures", name, 1, true)
	elseif pending.res then
		Credit("res", name, 1, true)
		DifferentDays(st, st.personDays, "res\0" .. tostring(name), day, "rescues")
	elseif pending.inGroup == true then
		Credit("groups", name, pending.group and type(pending.group.members) == "table"
			and #pending.group.members + 1 or 1, true)
	else
		Credit("strangers", name, 1, true)
		DifferentDays(st, st.strangerDays, name, day, "strangerDays")
	end
	Recheck(st, true)
	Bump()
end

local function OnLetGo()
	if not Active() then return end
	State().dirtyDays[Day()] = true
end

local function OnRefused(_, name)
	if not Active() then return end
	Credit("refused", name, 1, true)
	Bump()
end

local function OnThanked(_, name)
	if not Active() then return end
	local st = State()
	local day = Day()
	Collect(st, st.thankDays, day, "thankDays")
	if Credit("thanks", name, 1, true) and not st.dirtyDays[day] then
		st.capped[day] = type(st.capped[day]) == "table" and st.capped[day] or {}
		if not st.capped[day].cleanDays then
			st.capped[day].cleanDays = true
			st.metrics.cleanDays = (st.metrics.cleanDays or 0) + 1
			Recheck(st, true)
		end
	end
	Bump()
end

local function OnService(_, kind, name)
	if not Active() then return end
	local st = State()
	if type(kind) == "string" then Collect(st, st.serviceKinds, kind, "serviceKinds") end
	Collect(st, st.servicePeople, name, "servicePeople")
	Credit("services", type(name) == "string" and name or kind, 1, true)
	Bump()
end

local function SeedRow(row)
	local st = State()
	local name = row.name
	local at = row.doneAt or row.at
	local day = Day(at)
	if row.kind == "received" then
		Collect(st, st.givers, name, "givers")
		Credit("received", name, 1, false, row.at)
	end
	if row.kind == "received" and row.state == "returned" then
		Credit("returns", name, 1, false, at)
		DifferentDays(st, st.personDays, name, day, "returnDays")
		if type(row.class) == "string" then Collect(st, st.classes, row.class, "classes") end
		if type(row.doneAt) == "number" and type(row.at) == "number"
			and row.doneAt - row.at <= 10 then Credit("quick", name, 1, false, at) end
	elseif row.kind == "given" and not row.asked then
		Collect(st, st.people, name, "people")
		Credit("given", name, 1, false, at)
		Credit(row.to == "group" and "groups" or "strangers", name, row.covered or 1, false, at)
		if row.to ~= "group" then DifferentDays(st, st.strangerDays, name, day, "strangerDays") end
	end
end

local function Initialize()
	if initialized then return end
	initialized = true
	local st = State()
	if not st.seeded then
		for _, row in ipairs(api:RecentLedgerEntries(200)) do SeedRow(row) end
		st.seeded = true
		Recheck(st, false)
	end
end

---------------------------------------------------------------------------
-- reading it: totals, the sorted list, a row's text
---------------------------------------------------------------------------

local function Totals(st)
	local points, medals, done, max = 0, 0, 0, 0
	for _, def in ipairs(DEFS) do
		local tier = st.earned[def.id] or 0
		points = points + PointsOf(def, tier)
		medals = medals + tier
		max = max + #def.goals
		if tier >= #def.goals then done = done + 1 end
	end
	local rank, nextRank = RANKS[1], nil
	for i, r in ipairs(RANKS) do
		if points >= r.at then rank, nextRank = r, RANKS[i + 1] end
	end
	return points, medals, max, done, rank, nextRank
end

-- How far toward the next goal, 0 to 1 (1 when every goal is met).
local function Closeness(st, def)
	local tier = st.earned[def.id] or 0
	local goal = def.goals[tier + 1]
	if not goal then return 1 end
	local from = def.goals[tier] or 0
	return math.max(0, math.min(1, (Value(st, def) - from) / math.max(1, goal - from)))
end

local listCache = { version = -1 }

local function List()
	local db = Database()
	local key = version .. ":" .. db.filter .. ":" .. db.sort .. ":" .. db.theme
	if listCache.key == key then return listCache.rows end
	local st = State()
	local rows = {}
	for _, def in ipairs(DEFS) do
		local tier = st.earned[def.id] or 0
		local keep = db.theme == "all" or def.theme == db.theme
		if db.filter == "earned" then keep = keep and tier > 0
		elseif db.filter == "progress" then keep = keep and tier < #def.goals and Value(st, def) > 0
		elseif db.filter == "locked" then keep = keep and tier == 0 end
		if keep then rows[#rows + 1] = def end
	end
	local sorts = {
		theme = function(a, b)
			local ta, tb = THEME[a.theme].order, THEME[b.theme].order
			if ta ~= tb then return ta < tb end
			return a.order < b.order
		end,
		closest = function(a, b)
			local ca, cb = Closeness(st, a), Closeness(st, b)
			-- Done ones last.
			if (ca >= 1) ~= (cb >= 1) then return cb >= 1 end
			if ca ~= cb then return ca > cb end
			return a.order < b.order
		end,
		recent = function(a, b)
			local wa, wb = st.when[a.id] or 0, st.when[b.id] or 0
			if wa ~= wb then return wa > wb end
			return a.order < b.order
		end,
		name = function(a, b)
			if a.name ~= b.name then return a.name < b.name end
			return a.order < b.order
		end,
	}
	table.sort(rows, sorts[db.sort])
	listCache.key, listCache.rows = key, rows
	return rows
end

local STATS = {
	{ "returns", L["Favours you returned"] }, { "quick", L["Returned within ten seconds"] },
	{ "received", L["Buffs other players gave you"] }, { "givers", L["Different people who buffed you"] },
	{ "given", L["Buffs you gave to other players"] }, { "people", L["Different people you gave something to"] },
	{ "strangers", L["Passers-by you buffed unprompted"] }, { "groups", L["Party and raid members you buffed"] },
	{ "res", L["People you brought back to life"] }, { "cures", L["People you cured"] },
	{ "asked", L["Requests you answered"] }, { "services", L["Services you gave"] },
	{ "thanks", L["People you thanked"] }, { "activeDays", L["Days with good manners"] },
	{ "bestStreak", L["Longest run of days"] },
}

ShowToast = function(def, tier, line)
	toastEpoch = toastEpoch + 1
	local epoch = toastEpoch
	if not toast then
		toast = CreateFrame("Frame", nil, UIParent)
		toast:SetSize(300, 58)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -80)
		toast:SetFrameStrata("DIALOG")
		toast.back = toast:CreateTexture(nil, "BACKGROUND")
		toast.back:SetAllPoints()
		toast.back:SetTexture("Interface\\Buttons\\WHITE8X8")
		toast.back:SetVertexColor(0.05, 0.05, 0.07, 0.94)
		toast.icon = toast:CreateTexture(nil, "ARTWORK")
		toast.icon:SetSize(36, 36)
		toast.icon:SetPoint("LEFT", toast, "LEFT", 11, 0)
		toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2)
		toast.title:SetJustifyH("LEFT")
		toast.detail = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		toast.detail:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
		toast.detail:SetPoint("RIGHT", toast, "RIGHT", -12, 0)
		toast.detail:SetJustifyH("LEFT")
	end
	local medal = MedalOf(def, tier)
	toast.icon:SetTexture(ICONS .. def.icon)
	toast.title:SetText(def.name .. (medal and (" -- " .. medal.name) or ""))
	toast.detail:SetText(line)
	toast:Show()
	C_Timer.After(4, function()
		if toast and epoch == toastEpoch and api:ModuleActive("achievements") then toast:Hide() end
	end)
end

api:RegisterCallback("CoreReady", Initialize)
-- Optional addons usually load after Manners has initialized. Replay the seed
-- directly in that case; `initialized` makes a later CoreReady harmless.
if api:GetDB() then Initialize() end
api:RegisterCallback("Favour.Received", OnReceived, A)
api:RegisterCallback("Favour.Settled", OnSettled, A)
api:RegisterCallback("Favour.LetGo", OnLetGo, A)
api:RegisterCallback("Favour.Refused", OnRefused, A)
api:RegisterCallback("Thanked", OnThanked, A)
api:RegisterCallback("Service.Given", OnService, A)

---------------------------------------------------------------------------
-- the page
---------------------------------------------------------------------------

-- What the board shows (Board.lua): one kind or every kind, what of it, and
-- in which order; a value it does not know is the default.
local VIEW_DEFAULT = { theme = "all", filter = "all", sort = "theme" }
local function SetView(field, value)
	local db = Database()
	if field == "theme" then
		db.theme = (value == "all" or THEME[value]) and value or "all"
	elseif field == "filter" or field == "sort" then
		db[field] = SETTINGS[field][value] and value or VIEW_DEFAULT[field]
	else
		return
	end
	Bump()
end

local function Options()
	local args = {}
	-- The board and the statistics are drawn by widgets of their own
	-- (Board.lua); the text here is what search and the simple view read.
	args.achievementBoard = { type = "description", order = 1, fontSize = "medium",
		name = function() return L["Achievements"] end }
	args.achievementStats = { type = "description", order = 100,
		name = function() return L["Statistics"] end }
	args.achievementNotification = {
		type = "select", name = L["Achievement notification"], order = 101, width = "full",
		values = { none = L["None"], toast = L["Small toast"], chat = L["One line in chat"] },
		sorting = { "none", "toast", "chat" },
		get = function() return Database().notification end,
		set = function(_, value)
			Database().notification = (value == "toast" or value == "chat") and value or "none"
		end,
	}
	args.achievementSound = {
		type = "toggle", name = L["Sound"], order = 102, width = "full",
		desc = L["Play a sound with an achievement notification."],
		disabled = function() return Database().notification == "none" end,
		get = function() return Database().sound == true end,
		set = function(_, value) Database().sound = value == true end,
	}
	args.achievementTest = {
		type = "execute", name = L["Show an example"], order = 103,
		desc = L["Shows the notification you chose, as an achievement would."],
		disabled = function() return Database().notification == "none" end,
		func = function() Notify(DEFS[1], 1) end,
	}
	args.achievementReset = {
		type = "execute", name = L["Start this character over"], order = 104,
		desc = L["Forget this character's achievements and counts. Other characters keep theirs."],
		confirm = true,
		confirmText = L["Forget every achievement and count for this character? This cannot be undone."],
		func = function()
			local db = Database()
			db.characters[CharacterKey()] = Fresh()
			State().seeded = true
			Bump()
		end,
	}
	return args
end

api:RegisterOptionsPage("achievements", function()
	local args = Options()
	for _, item in pairs(args) do
		local own = item.hidden
		item.hidden = function(...)
			if not Active() then return true end
			return own and own(...) or false
		end
	end
	return { type = "group", name = L["Achievements"], args = args }
end, {
	title = L["Achievements"],
	blurb = L["Quiet rewards for good manners: returning favours, helping strangers, answering and thanking."],
	icon = "Interface\\Icons\\INV_Misc_Coin_01",
	sections = {
		{ key = "achievements.board", title = L["Your manners"], items = {
			{ "achievements.achievementBoard", widget = "achievementBoard" },
		} },
		{ key = "achievements.stats", title = L["Statistics"], fold = true, items = {
			{ "achievements.achievementStats", widget = "achievementStats" },
		} },
		{ key = "achievements.notifications", title = L["Achievement notification"], fold = true, items = {
			"achievements.achievementNotification", "achievements.achievementSound",
			{ "achievements.achievementTest", buttons = true },
			{ "achievements.achievementReset", buttons = true },
		} },
	},
	subpages = {
		{ "achievements.board", title = L["Achievements"] },
		{ "achievements.stats", "achievements.notifications", title = L["Statistics and settings"] },
	},
}, "modules")
do
	local layout = ns.WindowLayout
	-- The simple view keeps the board: where you stand and what you earned.
	if layout and layout.simple and type(layout.simple.items) == "table" then
		layout.simple.items["achievements.achievementBoard"] = true
	end
	-- The board and the statistics run the page's whole width.
	if layout and type(layout.spans) == "table" then
		layout.spans["achievements.board"] = true
		layout.spans["achievements.stats"] = true
	end
end

-- For the tests and /manners debug: the definitions and the reading of a row.
A.DEFS, A.List, A.Totals, A.State = DEFS, List, Totals, State
-- And what the board (Board.lua) draws with.
A.THEMES, A.THEME, A.MEDALS, A.RANKS, A.STATS = THEMES, THEME, MEDALS, RANKS, STATS
A.ICONS, A.LOCKED_ICON = ICONS, LOCKED_ICON
A.MedalOf, A.PointsOf, A.Value, A.Closeness, A.Day, A.Database = MedalOf, PointsOf, Value, Closeness, Day, Database
A.SetView, A.Active = SetView, Active
function A.Version() return version end
ns.Achievements = A
