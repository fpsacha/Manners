-- Manners: Achievements -- quiet, read-only manners achievements.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("achievements"), "Manners module API is missing")
local L = ns.L
local A = {}
local initialized = false
local recent = {}
local pane
local toast
local toastEpoch = 0
local ShowToast

local function Active()
	return api:ModuleActive("achievements") == true
end

api:RegisterModuleLifecycle("achievements", function()
	toastEpoch = toastEpoch + 1
	if toast then toast:Hide() end
end, function() end)

local TIERS = { 10, 100, 1000 }
local TIER_NAMES = { L["Bronze"], L["Silver"], L["Gold"] }
local THEMES = {
	{ id = "gratitude", name = L["Gratitude"], colour = { 0.96, 0.73, 0.35 } },
	{ id = "generosity", name = L["Generosity"], colour = { 0.35, 0.75, 0.92 } },
	{ id = "fellowship", name = L["Fellowship"], colour = { 0.50, 0.82, 0.55 } },
	{ id = "courtesy", name = L["Courtesy"], colour = { 0.78, 0.58, 0.92 } },
}

-- The thirteen earlier ideas, expanded into three tiers each, plus hidden
-- moments. The same set is kept independently for every character/class.
local DEFS = {
	{ id = "first", theme = "gratitude", metric = "returns",
		name = L["Much Obliged"], desc = L["Return your first favour."] },
	{ id = "hundred", theme = "gratitude", metric = "returns",
		name = L["A Hundred Thank-Yous"], desc = L["Return a hundred favours."] },
	{ id = "swift", theme = "gratitude", metric = "quick", hidden = true,
		name = L["Quick to Thank"], desc = L["Return a favour within ten seconds."] },
	{ id = "week", theme = "gratitude", metric = "cleanDays", hidden = true,
		name = L["A Week Without a Debt"], desc = L["Return every favour for a week: ten or more, on at least five days, none left unreturned."] },

	{ id = "strangers", theme = "generosity", metric = "strangers",
		name = L["The Kindness of Strangers"], desc = L["Buff a hundred strangers unprompted."] },
	{ id = "classes", theme = "generosity", metric = "classes",
		name = L["All Walks of Life"], desc = L["Return favours to people of five different classes."] },
	{ id = "day10", theme = "generosity", metric = "differentDaily",
		name = L["Thank You, Everyone"], desc = L["Return favours to ten different people in one day."] },
	{ id = "threedays", theme = "generosity", metric = "strangerDays", hidden = true,
		name = L["A Familiar Kindness"], desc = L["Buff the same stranger on three different days."] },

	{ id = "regular", theme = "fellowship", metric = "returnDays",
		name = L["Old Acquaintance"], desc = L["Thank the same person on ten different days."] },
	{ id = "raid", theme = "fellowship", metric = "groups", hidden = true,
		name = L["Nobody Left Out"], desc = L["Give one of your buffs to everybody in your raid in one sitting."] },
	{ id = "res", theme = "fellowship", metric = "res",
		name = L["Back on Your Feet"], desc = L["Bring somebody back to life through the prompt."] },
	{ id = "guardian", theme = "fellowship", metric = "rescues", hidden = true,
		name = L["Steady Hands"], desc = L["Resurrect the same person on three different days."] },

	{ id = "asked", theme = "courtesy", metric = "asked",
		name = L["You Only Had to Ask"], desc = L["Answer a request made in chat."] },
	{ id = "cure", theme = "courtesy", metric = "cures",
		name = L["A Clean Bill of Health"], desc = L["Cure somebody through the prompt."] },
	{ id = "courtesy", theme = "courtesy", metric = "services",
		name = L["At Your Service"], desc = L["Conjure, port or summon on request."] },
	{ id = "thanks", theme = "courtesy", metric = "thanks", hidden = true,
		name = L["The Polite Reply"], desc = L["Thank a different person on a different day."] },
}

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

local function Database()
	if type(MannersAchievementsDB) ~= "table" then MannersAchievementsDB = {} end
	local db = MannersAchievementsDB
	db.characters = type(db.characters) == "table" and db.characters or {}
	local notification = db.notification
	if notification ~= "toast" and notification ~= "chat" then notification = "none" end
	db.notification = notification
	db.sound = db.sound == true
	return db
end

local function State()
	local db = Database()
	local key = CharacterKey()
	local st = db.characters[key]
	if type(st) ~= "table" then
		st = { class = PlainClass(), metrics = {}, earned = {}, capped = {},
			personDays = {}, strangerDays = {}, classes = {}, dirtyDays = {}, seeded = false }
		db.characters[key] = st
	end
	st.metrics = type(st.metrics) == "table" and st.metrics or {}
	st.earned = type(st.earned) == "table" and st.earned or {}
	st.capped = type(st.capped) == "table" and st.capped or {}
	st.personDays = type(st.personDays) == "table" and st.personDays or {}
	st.strangerDays = type(st.strangerDays) == "table" and st.strangerDays or {}
	st.classes = type(st.classes) == "table" and st.classes or {}
	st.dirtyDays = type(st.dirtyDays) == "table" and st.dirtyDays or {}
	return st
end

local function Value(st, def)
	local metrics = st.metrics
	if def.metric == "classes" then
		local n = 0
		for _ in pairs(st.classes) do n = n + 1 end
		return n
	elseif def.metric == "differentDaily" or def.metric == "cleanDays"
		or def.metric == "returnDays" or def.metric == "strangerDays"
		or def.metric == "rescues" or def.metric == "thanks" then
		return metrics[def.metric] or 0
	end
	return metrics[def.metric] or 0
end

local function Tier(progress)
	local result = 0
	for i, goal in ipairs(TIERS) do
		if progress >= goal then result = i end
	end
	return result
end

local function Notify(def, tier)
	local db = Database()
	if db.notification == "none" then return end
	local line = L["%s reached %s: %s"]:format(def.name, TIER_NAMES[tier], def.desc)
	if db.notification == "chat" and ns and ns.addon then
		ns.addon:Print(line)
	elseif db.notification == "toast" then
		ShowToast(def, tier, line)
	end
	if db.sound and type(PlaySound) == "function" then
		pcall(PlaySound, 888)
	end
end

local function Recheck(st, announce)
	for _, def in ipairs(DEFS) do
		local tier = Tier(Value(st, def))
		local before = st.earned[def.id] or 0
		if tier > before then
			st.earned[def.id] = tier
			if announce then Notify(def, tier) end
		end
	end
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
	Recheck(st, announce ~= false)
	return true
end

local function DifferentDays(st, store, name, day, metric)
	if type(name) ~= "string" or name == "" then return end
	store[name] = type(store[name]) == "table" and store[name] or {}
	if not store[name][day] then
		store[name][day] = true
		local count = 0
		for _ in pairs(store[name]) do count = count + 1 end
		st.metrics[metric] = math.max(st.metrics[metric] or 0, count)
	end
end

local function OnReceived(_, seen)
	if not Active() then return end
	if type(seen) ~= "table" or type(seen.name) ~= "string" then return end
	recent[seen.name] = GetTime()
	State().dirtyDays[Day()] = nil
end

local function OnSettled(_, name, debt, pending)
	if not Active() then return end
	pending = type(pending) == "table" and pending or {}
	local st = State()
	local day = Day()
	if debt then
		if Credit("returns", name, 1, true) then
			DifferentDays(st, st.personDays, name, day, "returnDays")
			local heard = recent[name]
			if type(heard) == "number" and GetTime() - heard <= 10 then Credit("quick", name, 1, true) end
			if type(debt.class) == "string" then st.classes[debt.class] = true end
			local people = st.capped[day] or {}
			local daily = 0
			for key in pairs(people) do
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
		DifferentDays(st, st.personDays, name, day, "rescues")
	elseif pending.inGroup == true then
		Credit("groups", name, pending.group and type(pending.group.members) == "table"
			and #pending.group.members + 1 or 1, true)
	else
		Credit("strangers", name, 1, true)
		local days = st.strangerDays
		DifferentDays(st, days, name, day, "strangerDays")
	end
	Recheck(st, true)
end

local function OnLetGo()
	if not Active() then return end
	State().dirtyDays[Day()] = true
end

local function OnThanked(_, name)
	if not Active() then return end
	local st = State()
	local day = Day()
	if Credit("thanks", name, 1, true) and not st.dirtyDays[day] then
		st.capped[day] = type(st.capped[day]) == "table" and st.capped[day] or {}
		if st.capped[day].cleanDays then return end
		st.capped[day].cleanDays = true
		st.metrics.cleanDays = (st.metrics.cleanDays or 0) + 1
		Recheck(st, true)
	end
end

local function OnService(_, kind, name)
	if not Active() then return end
	Credit("services", type(name) == "string" and name or kind, 1, true)
end

local function SeedRow(row)
	local st = State()
	local name = row.name
	local at = row.doneAt or row.at
	local day = Day(at)
	if row.kind == "received" and row.state == "returned" then
		Credit("returns", name, 1, false, at)
		DifferentDays(st, st.personDays, name, day, "returnDays")
		if type(row.class) == "string" then st.classes[row.class] = true end
		if type(row.doneAt) == "number" and type(row.at) == "number"
			and row.doneAt - row.at <= 10 then Credit("quick", name, 1, false, at) end
	elseif row.kind == "given" and not row.asked then
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

local function ProgressForTheme(theme)
	local st = State()
	local chosen
	for _, def in ipairs(DEFS) do
		if def.theme == theme and (st.earned[def.id] or 0) < 3 and not chosen then
			chosen = def
		end
	end
	if not chosen then
		chosen = DEFS[1]
		for _, def in ipairs(DEFS) do
			if def.theme == theme and Value(st, def) >= Value(st, chosen) then chosen = def end
		end
	end
	return chosen, st
end

local function Text(parent, text, size, colour)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, size, "")
	fs:SetTextColor(unpack(colour or { 0.9, 0.9, 0.92 }))
	fs:SetJustifyH("LEFT")
	fs:SetText(text or "")
	return fs
end

local function Paint(_, host)
	if not pane then
		pane = { rows = {} }
		pane.class = Text(host, "", 10, { 0.65, 0.65, 0.68 })
		pane.class:SetPoint("TOPLEFT", host, "TOPLEFT", 2, 0)
		for i, theme in ipairs(THEMES) do
			local row = CreateFrame("Frame", nil, host)
			row:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -(i - 1) * 58 - 20)
			row:SetPoint("RIGHT", host, "RIGHT", -2, 0)
			row:SetHeight(50)
			row.name = Text(row, "", 12, theme.colour)
			row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			row.goal = Text(row, "", 10, { 0.75, 0.75, 0.78 })
			row.goal:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
			row.track = row:CreateTexture(nil, "BACKGROUND")
			row.track:SetTexture("Interface\\Buttons\\WHITE8X8")
			row.track:SetVertexColor(1, 1, 1, 0.08)
			row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
			row.track:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 3)
			row.track:SetHeight(5)
			row.fill = row:CreateTexture(nil, "BORDER")
			row.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
			row.fill:SetVertexColor(theme.colour[1], theme.colour[2], theme.colour[3], 0.9)
			row.fill:SetPoint("BOTTOMLEFT", row.track, "BOTTOMLEFT")
			row.fill:SetHeight(5)
			pane.rows[i] = row
		end
	end
	pane.class:SetText(L["Your %s manners"]:format(PlainClass()))
	local totalWidth = host:GetWidth() - 4
	for i, theme in ipairs(THEMES) do
		local def, st = ProgressForTheme(theme.id)
		local earned, progress = st.earned[def.id] or 0, Value(st, def)
		local tier = math.min(3, earned + 1)
		local goal = TIERS[tier]
		local row = pane.rows[i]
		local name = def.hidden and earned == 0 and L["A hidden moment"] or def.name
		row.name:SetText(theme.name .. " -- " .. name .. " (" .. TIER_NAMES[tier] .. ")")
		row.goal:SetText(def.hidden and earned == 0
			and L["Good manners will reveal it."] or L["%d / %d -- %s"]:format(progress, goal, def.desc))
		row.fill:SetWidth(math.max(1, totalWidth * math.min(1, progress / goal)))
	end
end

ShowToast = function(def, tier, line)
	toastEpoch = toastEpoch + 1
	local epoch = toastEpoch
	if not toast then
		toast = CreateFrame("Frame", nil, UIParent)
		toast:SetSize(280, 54)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -80)
		toast:SetFrameStrata("DIALOG")
		toast.back = toast:CreateTexture(nil, "BACKGROUND")
		toast.back:SetAllPoints()
		toast.back:SetTexture("Interface\\Buttons\\WHITE8X8")
		toast.back:SetVertexColor(0.05, 0.05, 0.07, 0.94)
		toast.title = Text(toast, "", 13, { 1, 0.82, 0.2 })
		toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", 12, -10)
		toast.detail = Text(toast, "", 10, { 0.85, 0.85, 0.88 })
		toast.detail:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
		toast.detail:SetPoint("RIGHT", toast, "RIGHT", -12, 0)
	end
	toast.title:SetText(def.name .. " -- " .. TIER_NAMES[tier])
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
api:RegisterCallback("Thanked", OnThanked, A)
api:RegisterCallback("Service.Given", OnService, A)
api:RegisterLedgerTab("achievements", L["Achievements"], Paint)

api:RegisterOptionsExtension("diagnostics", function(_, args)
	args.achievementIntro = { type = "description", order = 91,
		name = L["Quiet rewards for returning favours and being useful to other players. Progress is capped once per person and achievement each day."] }
	args.achievementNotification = {
		type = "select", name = L["Achievement notification"], order = 92, width = "full",
		values = { none = L["None"], toast = L["Small toast"], chat = L["One line in chat"] },
		sorting = { "none", "toast", "chat" },
		get = function() return Database().notification end,
		set = function(_, value)
			Database().notification = (value == "toast" or value == "chat") and value or "none"
		end,
	}
	args.achievementSound = {
		type = "toggle", name = L["Sound"], order = 93, width = "full",
		desc = L["Play a sound with an achievement notification."],
		disabled = function() return Database().notification == "none" end,
		get = function() return Database().sound == true end,
		set = function(_, value) Database().sound = value == true end,
	}
end)
api:AddLayoutSection("diagnostics", {
	key = "diagnostics.achievements", title = L["Achievements"], items = {
		"diagnostics.achievementIntro", "diagnostics.achievementNotification",
		"diagnostics.achievementSound",
	},
})
