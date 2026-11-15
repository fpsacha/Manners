-- Manners -- the hall of fame's proof: a certificate made to be photographed.
--
-- A code alone proves nothing (Hall.lua: its arithmetic is in the open), so a
-- place among the Gentlefolk of Good Manners is asked for with a screenshot.
-- With every milestone the character can earn, the favour ledger's Milestones
-- tab wears a certificate beside the window: who, which class, which client,
-- the day the last milestone was earned, how many, every milestone with its
-- date, the code in full and the build. One screenshot holds it and the tab's
-- own rows; the player posts it with the code on the "Hall of fame" form
-- (.github/ISSUE_TEMPLATE/hall-of-fame.yml), and the author compares the two
-- (`python tools/hall.py check <code>` says what the picture must show).
--
-- Everything on it is read back out of the code (Hall.Decode of Hall.Code), so
-- the picture and the code cannot say two different things. Hidden while
-- milestones are off, before the last one is earned and on every other tab.
-- Nothing here sends anything anywhere: the game takes the picture, the player
-- posts it.
--
-- Loaded after Hall.lua. Ledger.lua's Render calls Hall.PaintCertificate, and
-- Ledger.Show takes the tab to open on; Start here's "Show my certificate"
-- (Options/Start.lua, general.hallCertificate) calls Hall.ShowCertificate.

local _, ns = ...
local L = ns.L

local Hall, M, Ledger = ns.Hall, ns.Milestones, ns.Ledger
if not (Hall and M and Ledger and Ledger.Kit) then return end

local K = Ledger.Kit
local plain = ns.plain

local TEXT = {
	-- Under the name and the class: the day of the last milestone.
	DATE = L["Every milestone earned on %s"],
	COUNT = L["%d of %d milestones"],
	CODE = L["Code"],
	-- The last line: what to do with the picture.
	HINT = L["Take a screenshot of this certificate (the Print Screen key) and post it with your code on the \"Hall of fame\" form."],
}

-- Wide enough for the heading in German, the longest.
local WIDTH = 320
local PAD = 16
local GAP = 6
-- How many characters of the code go on a line: capitals and digits at CODE_SIZE
-- fill the certificate's width at about this many.
local CODE_WIDTH = 30
local CODE_SIZE = 13
local CODE_LINES = 8
local ROW_HEIGHT = 15
local DATE_WIDTH = 74
-- Thirteen milestones exist (Milestones.lua, LIST); no class can earn them all.
local MAX_ROWS = 13
local GOLD = { 1, 0.82, 0 }

---------------------------------------------------------------------------
-- what it says
---------------------------------------------------------------------------

local function Day(at)
	local ok, text = pcall(_G.date, "%Y-%m-%d", at)
	return ok and type(text) == "string" and text or ""
end

-- The code cut into lines of at most `width` characters, of about one length,
-- after a dash where one falls near: a font string does not wrap a word of
-- seventy letters. Joined again they are the code, to the letter.
function Hall.CodeLines(code, width)
	local lines = {}
	width = width or CODE_WIDTH
	local rest = tostring(code or "")
	local target = math.ceil(#rest / math.ceil(#rest / width))
	while #rest > width do
		local cut = target
		for i = width, math.max(1, target - 8), -1 do
			if rest:sub(i, i) == "-" and (cut == target or math.abs(i - target) < math.abs(cut - target)) then
				cut = i
			end
		end
		lines[#lines + 1] = rest:sub(1, cut)
		rest = rest:sub(cut + 1)
	end
	if rest ~= "" then lines[#lines + 1] = rest end
	return lines
end

-- What the certificate says, or nil while there is none: milestones off, or
-- one still to earn. Name, realm, class, client and date are the code's own.
function Hall.Certificate()
	if not Hall.Shown() then return nil end
	local code = Hall.Code()
	local who = code and Hall.Decode(code)
	if not who then return nil end
	local earned, of = Hall.Progress()
	local name = who.name:gsub("|", "")
	if who.realm ~= "" then name = name .. "-" .. who.realm:gsub("|", "") end
	local rows = {}
	for _, row in ipairs(M.Rows()) do
		if row.earnedAt and #rows < MAX_ROWS then
			rows[#rows + 1] = { name = row.def.name, date = Day(math.abs(row.earnedAt)) }
		end
	end
	return {
		code = code,
		name = name,
		class = who.class,
		className = ns.ClassName and ns.ClassName(who.class) or who.class,
		clientName = Hall.CLIENTS[who.client] or who.client,
		date = ("%s-%s-%s"):format(who.date:sub(1, 4), who.date:sub(5, 6), who.date:sub(7, 8)),
		earned = earned,
		of = of,
		rows = rows,
		build = "Manners " .. tostring(ns.BUILD or ""),
	}
end

---------------------------------------------------------------------------
-- the panel beside the ledger window
---------------------------------------------------------------------------

local panel

local function Coloured(name, class)
	local colours = _G.RAID_CLASS_COLORS
	local c = type(class) == "string" and type(colours) == "table" and colours[class]
	local code = type(c) == "table" and plain(c.colorStr)
	if type(code) == "string" then return ("|c%s%s|r"):format(code, name) end
	return name
end

-- A line across the panel, hung by its two top corners as the window hangs
-- every string, centred.
local function Line(size, colour)
	local fs = K.Text(panel, size, colour)
	fs:SetJustifyH("CENTER")
	return fs
end

local function Hang(fs, y, height)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
	fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, y)
	return y - height
end

local function Rule()
	local t = K.Solid(panel, "ARTWORK")
	t:SetHeight(1)
	t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
	return t
end

local function Build(window)
	panel = CreateFrame("Frame", "MannersCertificate", window)
	panel:SetWidth(WIDTH)
	panel:EnableMouse(true)
	panel:Hide()

	local shadow = K.Solid(panel, "BACKGROUND", -7)
	shadow:SetPoint("TOPLEFT", -2, 2)
	shadow:SetPoint("BOTTOMRIGHT", 2, -2)
	shadow:SetVertexColor(0, 0, 0, 0.32)
	local body = K.Solid(panel, "BACKGROUND", -6)
	body:SetAllPoints()
	body:SetVertexColor(0.05, 0.045, 0.035, 0.96)
	-- A gilt frame a little inside the edge, as a certificate has.
	for _, edge in ipairs({
		{ "TOPLEFT", "TOPRIGHT", 5, -5, -5, -5 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 5, 5, -5, 5 },
		{ "TOPLEFT", "BOTTOMLEFT", 5, -5, 5, 5 }, { "TOPRIGHT", "BOTTOMRIGHT", -5, -5, -5, 5 },
	}) do
		local t = K.Solid(panel, "BORDER")
		t:SetPoint(edge[1], panel, edge[1], edge[3], edge[4])
		t:SetPoint(edge[2], panel, edge[2], edge[5], edge[6])
		if edge[4] == edge[6] then t:SetHeight(1) else t:SetWidth(1) end
		t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
	end

	panel.logo = panel:CreateTexture(nil, "ARTWORK")
	panel.logo:SetTexture(K.LOGO)
	panel.logo:SetSize(30, 30)
	panel.logo:SetPoint("TOP", panel, "TOP", 0, -16)

	panel.heading = Line(15, GOLD)
	panel.heading:SetText(Hall.TEXT.TITLE)
	panel.name = Line(18, K.INK)
	panel.detail = Line(12, K.INK_SOFT)
	panel.date = Line(12, K.INK)
	panel.count = Line(12, K.COLOUR.returned)
	panel.rules = { Rule(), Rule(), Rule() }

	panel.rows = {}
	for i = 1, MAX_ROWS do
		local row = { name = K.Text(panel, 11, K.RANK_INK), date = K.Text(panel, 11, K.INK_SOFT) }
		row.date:SetJustifyH("RIGHT")
		row.date:SetWidth(DATE_WIDTH)
		panel.rows[i] = row
	end

	panel.codeLabel = Line(10, K.INK_FAINT)
	panel.codeLabel:SetText(TEXT.CODE)
	panel.codeLines = {}
	for i = 1, CODE_LINES do panel.codeLines[i] = Line(CODE_SIZE, K.INK) end

	panel.hint = Line(10, K.INK_FAINT)
	K.Wrap(panel.hint, 3)
	panel.hint:SetText(TEXT.HINT)
	panel.build = Line(10, K.INK_SOFT)

	window.certificate = panel
end

-- Beside the window, on the side the screen has room for.
local function Place(window)
	local right = plain(window.GetRight and window:GetRight())
	local screen = plain(UIParent and UIParent.GetWidth and UIParent:GetWidth())
	panel:ClearAllPoints()
	if type(right) == "number" and type(screen) == "number" and right + WIDTH + GAP > screen then
		panel:SetPoint("TOPRIGHT", window, "TOPLEFT", -GAP, 0)
	else
		panel:SetPoint("TOPLEFT", window, "TOPRIGHT", GAP, 0)
	end
end

local function RuleAt(i, y)
	local t = panel.rules[i]
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
	t:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, y)
	return y - 9
end

-- Ledger.lua's Render, each time the window is drawn: `onTab` while the
-- Milestones tab is the one on show.
function Hall.PaintCertificate(window, onTab)
	local facts = onTab and window and Hall.Certificate() or nil
	if not facts then
		if panel then panel:Hide() end
		return
	end
	if not panel then Build(window) end
	Place(window)

	local y = Hang(panel.heading, -54, 26)
	y = RuleAt(1, y)
	panel.name:SetText(Coloured(facts.name, facts.class))
	y = Hang(panel.name, y - 2, 26)
	panel.detail:SetText(("%s, %s"):format(facts.className, facts.clientName))
	y = Hang(panel.detail, y, 20)
	panel.date:SetText(TEXT.DATE:format(facts.date))
	y = Hang(panel.date, y, 18)
	panel.count:SetText(TEXT.COUNT:format(facts.earned, facts.of))
	y = Hang(panel.count, y, 22)
	y = RuleAt(2, y)

	for i, row in ipairs(panel.rows) do
		local fact = facts.rows[i]
		row.name:SetShown(fact ~= nil)
		row.date:SetShown(fact ~= nil)
		if fact then
			row.name:SetText(fact.name)
			row.date:SetText(fact.date)
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
			row.name:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + DATE_WIDTH + 6), y)
			row.date:ClearAllPoints()
			row.date:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, y)
			y = y - ROW_HEIGHT
		end
	end
	y = RuleAt(3, y - 5)

	y = Hang(panel.codeLabel, y, 15)
	local lines = Hall.CodeLines(facts.code, CODE_WIDTH)
	-- A code longer than the lines there are (two names of forty-eight bytes):
	-- cut evenly, wherever that falls, rather than a code cut short.
	if #lines > CODE_LINES then
		local each = math.ceil(#facts.code / CODE_LINES)
		lines = {}
		for from = 1, #facts.code, each do lines[#lines + 1] = facts.code:sub(from, from + each - 1) end
	end
	for i, fs in ipairs(panel.codeLines) do
		fs:SetShown(lines[i] ~= nil)
		if lines[i] then
			fs:SetText(lines[i])
			y = Hang(fs, y, CODE_SIZE + 4)
		end
	end

	y = Hang(panel.hint, y - 10, 38)
	panel.build:SetText(facts.build)
	y = Hang(panel.build, y, 14)
	panel:SetHeight(-y + PAD)
	panel:Show()
end

-- Start here's button: the ledger, on the tab the certificate is on.
function Hall.ShowCertificate()
	Ledger.Show("milestones")
end
