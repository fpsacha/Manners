-- Manners: Achievements -- the board and the statistics, drawn as widgets of
-- the options window (Options/Window/Widgets.lua: a kind is Build, Refresh,
-- Layout). Asked for by the addon's owner: the page was lines of small text
-- with bars drawn in the text, split into two narrow columns.
--
-- The board, top to bottom, across the page's whole width:
--   * where you stand: the rank in large type, three figures (points, medals,
--     achievements complete), a real bar to the next rank and its words;
--   * the medals earned lately, as icons with their medal's colour round them,
--     each naming itself under the mouse;
--   * three rows of tabs: the kind, what to show, the order;
--   * the achievements as cards, as many to a row as fit (two in the usual
--     window, one when narrow, three when wide), every one of them: a card is
--     its icon, its name, its kind, its line, a bar to the next medal with the
--     count, and a pip a medal, coloured once earned. A hidden one not earned
--     yet keeps its secret. The card's tooltip has every goal.
-- The statistics are tiles: the number large, its name under it.
--
-- Nothing here runs on a timer: what is drawn is set when the page is painted
-- (Refresh) and placed when it is laid out (Layout).

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("achievements"), "Manners module API is missing")
local L = ns.L
local A = ns.Achievements
local W = ns.WindowWidgets
if not (A and W and W.KIND) then return end
local T, KIND = W.Theme, W.KIND

local PAD, GAP = 9, 6
local ICON, PIP = 34, 9
-- Two columns at most: three made the names cut off and the lines small.
local CARD_MIN, CARD_MAX_COLS = 290, 2
local BAR_H = 6
local RECENT, RECENT_ICON = 6, 30
local TAB_H, TAB_PAD, TAB_GAP = 22, 10, 4

local CARD_FILL = { 1, 1, 1, 0.035 }
local CARD_EDGE = { 1, 1, 1, 0.09 }
local TRACK = { 0.11, 0.11, 0.13 }
local PIP_OFF = { 0.20, 0.20, 0.23 }

local function Rgb(hex)
	return { (tonumber(hex:sub(1, 2), 16) or 255) / 255, (tonumber(hex:sub(3, 4), 16) or 255) / 255,
		(tonumber(hex:sub(5, 6), 16) or 255) / 255 }
end

local function Repaint(row)
	if ns.RefreshOptionsDisplay then api:Guard("achievements repaint", ns.RefreshOptionsDisplay) end
	W.Relayout(row)
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A bar: a dark track and a fill, the fill's share kept until it is laid out.
local function Bar(parent)
	local bar = CreateFrame("Frame", nil, parent)
	bar.track = W.Solid(bar, "BACKGROUND", 0, TRACK)
	bar.track:SetAllPoints(bar)
	bar.fill = W.Solid(bar, "ARTWORK", 0, T.gold)
	bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bar.share = 0
	return bar
end

local function BarWidth(bar, width)
	bar:SetWidth(math.max(1, width))
	local w = math.floor(width * math.max(0, math.min(1, bar.share)) + 0.5)
	bar.fill:SetWidth(math.max(1, w))
	bar.fill:SetShown(w > 0)
end

-- A tab: words that turn gold with a gold line under them when chosen.
local function TabEnter(b)
	if not b.on then W.TextColour(b.label, T.ink) end
end
local function TabLeave(b)
	if not b.on then W.TextColour(b.label, T.inkSoft) end
end
local function TabClick(b)
	A.SetView(b.field, b.value)
	Repaint(b.row)
end

local function Tab(row, field, value)
	local b = CreateFrame("Button", nil, row.frame)
	b.row, b.field, b.value = row, field, value
	b.label = W.Text(b, T.fonts.normalSmall, T.inkSoft)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.line = W.Solid(b, "ARTWORK", 0, T.gold)
	b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.line:SetHeight(2)
	b.wash = W.Solid(b, "BACKGROUND", 0, { 1, 0.82, 0, 0.08 })
	b.wash:SetAllPoints(b)
	W.Solid(b, "HIGHLIGHT", nil, { 1, 1, 1, 0.06 }):SetAllPoints(b)
	b:SetScript("OnClick", function(self) api:Guard("achievement tab", TabClick, self) end)
	b:SetScript("OnEnter", function(self) api:Guard("achievement tab", TabEnter, self) end)
	b:SetScript("OnLeave", function(self) api:Guard("achievement tab", TabLeave, self) end)
	return b
end

local function TabLook(b, text, on)
	b.on = on
	b.label:SetText(text)
	W.TextColour(b.label, on and T.gold or T.inkSoft)
	b.line:SetShown(on)
	b.wash:SetShown(on)
	b:SetSize(math.ceil(W.Measure(b.label)) + 2 * TAB_PAD, TAB_H)
end

-- A row of tabs from x, wrapping at the width, after a caption. Answers the
-- height it took.
local function PlaceTabs(row, caption, tabs, y, width)
	caption:ClearAllPoints()
	caption:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(y + 5))
	local x0 = math.ceil(W.Measure(caption)) + 10
	local x, top = x0, y
	for _, b in ipairs(tabs) do
		local w = b:GetWidth()
		if x > x0 and x + w > width then
			x, top = x0, top + TAB_H + TAB_GAP
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -top)
		b:Show()
		x = x + w + TAB_GAP
	end
	return top + TAB_H - y
end

---------------------------------------------------------------------------
-- a card
---------------------------------------------------------------------------

local function CardEnter(card)
	local def = card.def
	if not def then return end
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	if card.secret then
		GameTooltip:AddLine(L["A hidden moment"], 1, 1, 1)
		GameTooltip:AddLine(L["Good manners will reveal it."], 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
		return
	end
	local st = A.State()
	local tier = st.earned[def.id] or 0
	GameTooltip:AddLine(def.name, 1, 1, 1)
	GameTooltip:AddLine(def.desc, 0.8, 0.8, 0.8, true)
	local progress = A.Value(st, def)
	for i, goal in ipairs(def.goals) do
		local medal = A.MedalOf(def, i)
		local c = Rgb(medal.colour)
		local done = i <= tier
		GameTooltip:AddDoubleLine(medal.name, L["%d / %d"]:format(math.min(progress, goal), goal),
			done and c[1] or 0.5, done and c[2] or 0.5, done and c[3] or 0.5, done and 1 or 0.6, done and 1 or 0.6, done and 1 or 0.6)
	end
	if st.when[def.id] then
		GameTooltip:AddLine(L["Completed on %s"]:format(date("%Y-%m-%d", st.when[def.id])), 0.5, 0.82, 0.55)
	end
	GameTooltip:Show()
end

local function Card(row)
	local card = CreateFrame("Button", nil, row.frame)
	card.fill = W.Solid(card, "BACKGROUND", 0, CARD_FILL)
	card.fill:SetAllPoints(card)
	card.edges = W.Border(card, CARD_EDGE)
	W.Solid(card, "HIGHLIGHT", nil, { 1, 1, 1, 0.04 }):SetAllPoints(card)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(ICON, ICON)
	card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
	card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	card.iconEdge = W.Solid(card, "BORDER", 0, { 0, 0, 0, 1 })
	card.iconEdge:SetPoint("TOPLEFT", card.icon, "TOPLEFT", -1, 1)
	card.iconEdge:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", 1, -1)
	card.title = W.Wrapping(W.Text(card, T.fonts.normal, T.white))
	if card.title.SetMaxLines then card.title:SetMaxLines(2) end
	card.kind = W.Text(card, T.fonts.small, T.hint)
	card.kind:SetJustifyH("RIGHT")
	card.kind:SetWordWrap(false)
	card.desc = W.Wrapping(W.Text(card, T.fonts.normalSmall, T.inkSoft))
	card.bar = Bar(card)
	card.bar:SetHeight(BAR_H)
	card.count = W.Text(card, T.fonts.small, T.ink)
	card.count:SetJustifyH("RIGHT")
	card.done = W.Text(card, T.fonts.small, T.green)
	card.pips = {}
	card:SetScript("OnEnter", function(self) api:Guard("achievement card", CardEnter, self) end)
	card:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return card
end

local function Pip(card, i)
	local pip = card.pips[i]
	if not pip then
		pip = W.Solid(card, "ARTWORK", 1, PIP_OFF)
		pip:SetSize(PIP, PIP)
		pip.edge = W.Solid(card, "BORDER", 1, { 0, 0, 0, 1 })
		pip.edge:SetPoint("TOPLEFT", pip, "TOPLEFT", -1, 1)
		pip.edge:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 1, -1)
		card.pips[i] = pip
	end
	return pip
end

-- What a card says, set when the page is painted.
local function Dress(card, def, st)
	card.def = def
	local theme = A.THEME[def.theme]
	local tier = st.earned[def.id] or 0
	local progress = A.Value(st, def)
	card.secret = def.hidden and tier == 0
	card.kind:SetText(theme.name)
	W.TextColour(card.kind, Rgb(theme.colour))
	local complete = tier >= #def.goals
	if card.secret then
		card.icon:SetTexture(A.LOCKED_ICON)
		card.title:SetText(L["A hidden moment"])
		card.desc:SetText(L["Good manners will reveal it."])
	else
		card.icon:SetTexture(A.ICONS .. def.icon)
		card.title:SetText(def.name)
		card.desc:SetText(def.desc)
	end
	-- Not started: the icon greyed, the name in plain ink.
	local started = tier > 0 or progress > 0
	if card.icon.SetDesaturated then card.icon:SetDesaturated(not started) end
	card.icon:SetAlpha(started and 1 or 0.55)
	W.TextColour(card.title, tier > 0 and T.white or T.ink)
	local medal = A.MedalOf(def, tier)
	W.BorderColour(card.edges, complete and medal and { Rgb(medal.colour)[1], Rgb(medal.colour)[2],
		Rgb(medal.colour)[3], 0.75 } or CARD_EDGE)
	card.pipCount = card.secret and 0 or #def.goals
	for i = 1, math.max(#card.pips, card.pipCount) do
		local pip = Pip(card, i)
		local on = i <= card.pipCount
		pip:SetShown(on)
		pip.edge:SetShown(on)
		if on then W.Colour(pip, i <= tier and Rgb(A.MedalOf(def, i).colour) or PIP_OFF) end
	end
	local nextGoal = def.goals[tier + 1]
	card.barShown = not card.secret and nextGoal ~= nil
	if card.barShown then
		card.bar.share = A.Closeness(st, def)
		W.Colour(card.bar.fill, Rgb(theme.colour))
		card.count:SetText(L["%d / %d"]:format(progress, nextGoal))
		card.done:SetText("")
	else
		card.count:SetText("")
		card.done:SetText(complete and st.when[def.id]
			and L["Completed on %s"]:format(date("%Y-%m-%d", st.when[def.id])) or "")
	end
	card.bar:SetShown(card.barShown)
	card.count:SetShown(card.barShown)
	card.done:SetShown(not card.barShown and card.done:GetText() ~= "")
end

-- Places what is in a card at a width; answers its height. The name with its
-- kind beside it and the medal pips at the right, the line under them, then
-- the bar and the count (or the day it was completed).
local function Fit(card, width)
	local x = PAD + ICON + 10
	local inner = width - x - PAD
	local pipsW = card.pipCount > 0 and card.pipCount * (PIP + 4) or 0
	local kindW = math.ceil(W.Measure(card.kind))
	card.kind:ClearAllPoints()
	card.kind:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(PAD + pipsW + (pipsW > 0 and 4 or 0)), -(PAD + 2))
	card.kind:SetWidth(kindW + 2)
	card.title:ClearAllPoints()
	card.title:SetPoint("TOPLEFT", card, "TOPLEFT", x, -PAD)
	card.title:SetWidth(math.max(1, inner - pipsW - kindW - 14))
	for i = 1, card.pipCount do
		local pip = card.pips[i]
		pip:ClearAllPoints()
		pip:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(PAD + (card.pipCount - i) * (PIP + 4)), -(PAD + 3))
	end
	local y = PAD + math.ceil(W.TextHeight(card.title)) + 4
	card.desc:ClearAllPoints()
	card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	card.desc:SetWidth(math.max(1, inner))
	y = y + math.ceil(W.TextHeight(card.desc)) + 7
	if card.barShown then
		local countW = 64
		card.count:ClearAllPoints()
		card.count:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y - 4))
		card.count:SetWidth(countW)
		card.bar:ClearAllPoints()
		card.bar:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
		BarWidth(card.bar, inner - countW - 8)
		y = y + BAR_H
	elseif card.done:IsShown() then
		card.done:ClearAllPoints()
		card.done:SetPoint("TOPLEFT", card, "TOPLEFT", x, -(y - 2))
		card.done:SetWidth(math.max(1, inner))
		y = y + math.ceil(W.TextHeight(card.done)) - 2
	end
	return math.max(y + PAD, PAD * 2 + ICON)
end

---------------------------------------------------------------------------
-- the board
---------------------------------------------------------------------------

local function RecentEnter(b)
	local def = b.def
	if not def then return end
	local st = A.State()
	local medal = A.MedalOf(def, st.earned[def.id] or 0)
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(def.name, 1, 1, 1)
	if medal then
		local c = Rgb(medal.colour)
		GameTooltip:AddLine(medal.name, c[1], c[2], c[3])
	end
	if st.when[def.id] then
		GameTooltip:AddLine(L["Completed on %s"]:format(date("%Y-%m-%d", st.when[def.id])), 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
end

local function Figure(row)
	local f = {}
	f.value = W.Text(row.head, T.fonts.large, T.white)
	f.label = W.Text(row.head, T.fonts.small, T.hint)
	return f
end

local function BuildBoard(row)
	-- Where you stand.
	row.head = CreateFrame("Frame", nil, row.frame)
	local back = W.Solid(row.head, "BACKGROUND", 0, { 1, 0.82, 0, 0.045 })
	back:SetAllPoints(row.head)
	W.Border(row.head, { 1, 0.82, 0, 0.22 })
	row.emblem = row.head:CreateTexture(nil, "ARTWORK")
	row.emblem:SetSize(52, 52)
	row.emblem:SetTexture("Interface\\AddOns\\Manners\\Textures\\Manners64")
	row.rank = W.Text(row.head, T.fonts.large, T.gold)
	row.rank:SetWordWrap(false)
	row.figures = { Figure(row), Figure(row), Figure(row) }
	row.rankBar = Bar(row.head)
	row.rankBar:SetHeight(8)
	row.toNext = W.Text(row.head, T.fonts.small, T.inkSoft)
	row.streak = W.Text(row.head, T.fonts.small, T.goldSoft)
	-- Earned lately.
	row.recentTitle = W.Text(row.frame, T.fonts.normalSmall, T.gold)
	row.recentTitle:SetText(L["Earned lately"])
	row.recentNone = W.Wrapping(W.Text(row.frame, T.fonts.small, T.hint))
	row.recentNone:SetText(L["Nothing earned yet. Return a favour to begin."])
	row.recent = {}
	for i = 1, RECENT do
		local b = CreateFrame("Button", nil, row.frame)
		b:SetSize(RECENT_ICON, RECENT_ICON)
		b.edge = W.Solid(b, "BACKGROUND", 0, T.gold)
		b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
		b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b:SetScript("OnEnter", function(self) api:Guard("achievement recent", RecentEnter, self) end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.recent[i] = b
	end
	-- The tabs.
	row.kindCaption = W.Text(row.frame, T.fonts.small, T.hint)
	row.kindCaption:SetText(L["Kind"])
	row.showCaption = W.Text(row.frame, T.fonts.small, T.hint)
	row.showCaption:SetText(L["Show"])
	row.sortCaption = W.Text(row.frame, T.fonts.small, T.hint)
	row.sortCaption:SetText(L["Sort by"])
	row.kindTabs = { Tab(row, "theme", "all") }
	for _, theme in ipairs(A.THEMES) do row.kindTabs[#row.kindTabs + 1] = Tab(row, "theme", theme.id) end
	row.showTabs = {}
	for _, v in ipairs({ "all", "earned", "progress", "locked" }) do row.showTabs[#row.showTabs + 1] = Tab(row, "filter", v) end
	row.sortTabs = {}
	for _, v in ipairs({ "theme", "closest", "recent", "name" }) do row.sortTabs[#row.sortTabs + 1] = Tab(row, "sort", v) end
	row.none = W.Wrapping(W.Text(row.frame, T.fonts.small, T.hint))
	row.none:SetText(L["Nothing matches. Choose another kind or show all."])
	row.cards = {}
end

local SHOW_WORDS = { all = L["All"], earned = L["Earned"], progress = L["In progress"], locked = L["Not started"] }
local SORT_WORDS = { theme = L["Kind"], closest = L["Closest to the next medal"], recent = L["Most recently earned"],
	name = L["Name"] }

local function RefreshBoard(row)
	local st = A.State()
	local db = A.Database()
	local points, medals, max, done, rank, nextRank = A.Totals(st)
	row.rank:SetText(rank.name)
	local figures = {
		{ tostring(points), L["Points"] },
		{ L["%d / %d"]:format(medals, max), L["Medals"] },
		{ L["%d / %d"]:format(done, #A.DEFS), L["Completed"] },
	}
	for i, f in ipairs(row.figures) do
		f.value:SetText(figures[i][1])
		f.label:SetText(figures[i][2])
	end
	if nextRank then
		row.rankBar.share = (points - rank.at) / math.max(1, nextRank.at - rank.at)
		row.toNext:SetText(L["%d points to %s"]:format(nextRank.at - points, nextRank.name))
	else
		row.rankBar.share = 1
		row.toNext:SetText("")
	end
	local streak = st.metrics.streak or 0
	row.streak:SetText(streak > 1 and st.days[A.Day()] and L["Good manners %d days in a row."]:format(streak) or "")
	-- Earned lately, newest first.
	local earned = {}
	for _, def in ipairs(A.DEFS) do
		if (st.earned[def.id] or 0) > 0 and st.when[def.id] then earned[#earned + 1] = def end
	end
	table.sort(earned, function(a, b) return st.when[a.id] > st.when[b.id] end)
	row.recentCount = math.min(RECENT, #earned)
	for i, b in ipairs(row.recent) do
		local def = earned[i]
		b.def = def
		if def then
			b.icon:SetTexture(A.ICONS .. def.icon)
			local medal = A.MedalOf(def, st.earned[def.id])
			W.Colour(b.edge, medal and Rgb(medal.colour) or T.gold)
		end
	end
	-- The tabs, each with how many it holds for a kind.
	local counts = { all = #A.DEFS }
	for _, def in ipairs(A.DEFS) do counts[def.theme] = (counts[def.theme] or 0) + 1 end
	for _, b in ipairs(row.kindTabs) do
		local name = b.value == "all" and L["Every kind"] or A.THEME[b.value].name
		TabLook(b, ("%s  |cff8e8b84%d|r"):format(name, counts[b.value] or 0), db.theme == b.value)
	end
	for _, b in ipairs(row.showTabs) do TabLook(b, SHOW_WORDS[b.value], db.filter == b.value) end
	for _, b in ipairs(row.sortTabs) do TabLook(b, SORT_WORDS[b.value], db.sort == b.value) end
	-- The cards.
	local list = A.List()
	for i, def in ipairs(list) do
		local card = row.cards[i] or Card(row)
		row.cards[i] = card
		Dress(card, def, st)
	end
	for i = #list + 1, #row.cards do row.cards[i]:Hide() end
	row.shown = #list
	local key = A.Version() .. ":" .. db.theme .. db.filter .. db.sort
	if row.drawn and row.drawn ~= key and row.width then W.Relayout(row) end
	row.drawn = key
end

local function LayoutBoard(row, width)
	-- Where you stand: the emblem, the rank and its bar on the left, the three
	-- figures on the right.
	local headH = row.streak:GetText() ~= "" and 88 or 74
	row.head:ClearAllPoints()
	row.head:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
	row.head:SetSize(width, headH)
	row.emblem:ClearAllPoints()
	row.emblem:SetPoint("TOPLEFT", row.head, "TOPLEFT", PAD, -PAD)
	local figW = width >= 560 and 92 or 0
	local left = PAD + 52 + 14
	local barW = width - left - PAD - figW * 3
	row.rank:ClearAllPoints()
	row.rank:SetPoint("TOPLEFT", row.head, "TOPLEFT", left, -(PAD + 2))
	row.rank:SetWidth(math.max(1, barW))
	row.rankBar:ClearAllPoints()
	row.rankBar:SetPoint("TOPLEFT", row.head, "TOPLEFT", left, -(PAD + 30))
	BarWidth(row.rankBar, barW)
	row.toNext:ClearAllPoints()
	row.toNext:SetPoint("TOPLEFT", row.rankBar, "BOTTOMLEFT", 0, -6)
	row.toNext:SetWidth(math.max(1, barW))
	row.streak:ClearAllPoints()
	row.streak:SetPoint("TOPLEFT", row.toNext, "BOTTOMLEFT", 0, -3)
	row.streak:SetWidth(math.max(1, barW))
	for i, f in ipairs(row.figures) do
		local shown = figW > 0
		f.value:SetShown(shown)
		f.label:SetShown(shown)
		if shown then
			local x = width - PAD - figW * (4 - i)
			f.value:ClearAllPoints()
			f.value:SetPoint("TOPLEFT", row.head, "TOPLEFT", x, -(PAD + 8))
			f.value:SetWidth(figW)
			f.label:ClearAllPoints()
			f.label:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -3)
			f.label:SetWidth(figW)
		end
	end
	local y = headH + 10
	-- Earned lately.
	local titleW = math.ceil(W.Measure(row.recentTitle)) + 14
	if row.recentCount == 0 then
		row.recentTitle:ClearAllPoints()
		row.recentTitle:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
		for _, b in ipairs(row.recent) do b:Hide() end
		row.recentNone:ClearAllPoints()
		row.recentNone:SetPoint("TOPLEFT", row.frame, "TOPLEFT", titleW, -y)
		row.recentNone:SetWidth(math.max(1, width - titleW))
		row.recentNone:Show()
		y = y + math.max(14, math.ceil(W.TextHeight(row.recentNone))) + 14
	else
		row.recentTitle:ClearAllPoints()
		row.recentTitle:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(y + 9))
		row.recentNone:Hide()
		for i, b in ipairs(row.recent) do
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", titleW + (i - 1) * (RECENT_ICON + 10), -(y + 2))
			b:SetShown(i <= row.recentCount)
		end
		y = y + RECENT_ICON + 14
	end
	-- The tabs: the kind on a row of its own, what to show and the order
	-- side by side where they fit.
	y = y + PlaceTabs(row, row.kindCaption, row.kindTabs, y, width) + 6
	local showW = 0
	for _, b in ipairs(row.showTabs) do showW = showW + b:GetWidth() + TAB_GAP end
	local split = math.ceil(W.Measure(row.showCaption)) + 10 + showW + 24
	local sortW = math.ceil(W.Measure(row.sortCaption)) + 10
	for _, b in ipairs(row.sortTabs) do sortW = sortW + b:GetWidth() + TAB_GAP end
	if split + sortW <= width then
		local h = PlaceTabs(row, row.showCaption, row.showTabs, y, split)
		row.sortCaption:ClearAllPoints()
		row.sortCaption:SetPoint("TOPLEFT", row.frame, "TOPLEFT", split, -(y + 5))
		local x = split + math.ceil(W.Measure(row.sortCaption)) + 10
		for _, b in ipairs(row.sortTabs) do
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -y)
			b:Show()
			x = x + b:GetWidth() + TAB_GAP
		end
		y = y + h + 12
	else
		y = y + PlaceTabs(row, row.showCaption, row.showTabs, y, width) + 6
		y = y + PlaceTabs(row, row.sortCaption, row.sortTabs, y, width) + 12
	end
	-- The cards, a row at a time, each row as tall as its tallest card.
	if row.shown == 0 then
		row.none:ClearAllPoints()
		row.none:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
		row.none:SetWidth(width)
		row.none:Show()
		return y + math.ceil(W.TextHeight(row.none))
	end
	row.none:Hide()
	local cols = math.max(1, math.min(CARD_MAX_COLS, math.floor((width + GAP) / (CARD_MIN + GAP))))
	local cardW = math.floor((width - (cols - 1) * GAP) / cols)
	row.cols = cols
	local i = 1
	while i <= row.shown do
		local tallest = 0
		for c = 0, cols - 1 do
			local card = row.cards[i + c]
			if card and i + c <= row.shown then tallest = math.max(tallest, Fit(card, cardW)) end
		end
		for c = 0, cols - 1 do
			local card = row.cards[i + c]
			if card and i + c <= row.shown then
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", row.frame, "TOPLEFT", c * (cardW + GAP), -y)
				card:SetSize(cardW, tallest)
				card:Show()
			end
		end
		y = y + tallest + GAP
		i = i + cols
	end
	return y - GAP
end

KIND.achievementBoard = {
	Build = BuildBoard,
	Refresh = function(row) api:Guard("achievement board", RefreshBoard, row) end,
	Layout = LayoutBoard,
}

---------------------------------------------------------------------------
-- the statistics
---------------------------------------------------------------------------

local TILE_MIN, TILE_H = 170, 50

KIND.achievementStats = {
	Build = function(row) row.tiles = {} end,
	Refresh = function(row)
		local st = A.State()
		for i, stat in ipairs(A.STATS) do
			local tile = row.tiles[i]
			if not tile then
				tile = CreateFrame("Frame", nil, row.frame)
				W.Solid(tile, "BACKGROUND", 0, CARD_FILL):SetAllPoints(tile)
				W.Border(tile, CARD_EDGE)
				tile.value = W.Text(tile, T.fonts.large, T.white)
				tile.value:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -8)
				tile.label = W.Text(tile, T.fonts.small, T.hint)
				tile.label:SetPoint("TOPLEFT", tile.value, "BOTTOMLEFT", 0, -3)
				tile.label:SetWordWrap(false)
				row.tiles[i] = tile
			end
			tile.value:SetText(tostring(st.metrics[stat[1]] or 0))
			tile.label:SetText(stat[2])
		end
	end,
	Layout = function(row, width)
		local cols = math.max(1, math.min(4, math.floor((width + GAP) / (TILE_MIN + GAP))))
		local w = math.floor((width - (cols - 1) * GAP) / cols)
		for i, tile in ipairs(row.tiles) do
			local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", row.frame, "TOPLEFT", c * (w + GAP), -r * (TILE_H + GAP))
			tile:SetSize(w, TILE_H)
			tile.label:SetWidth(w - 20)
			tile:Show()
		end
		local rows = math.ceil(#row.tiles / cols)
		return rows * TILE_H + math.max(0, rows - 1) * GAP
	end,
}
