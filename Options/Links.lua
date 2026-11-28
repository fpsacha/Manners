-- Manners -- Links: where to find Manners outside the game, to copy.
--
-- The footer's square Links button opens a small window with the Discord
-- server, the CurseForge page and GitHub, each in a read-only box with
-- Select all: the game opens no browser, so a link is copied, not clicked.

local ns = select(2, ...)
local L = ns.L

local Links = {}
ns.Links = Links

Links.LIST = {
	{ key = "discord", name = L["Discord: questions, ideas and news"], url = "https://discord.gg/bdrDXGXkzA" },
	{ key = "curseforge", name = L["CurseForge: downloads and comments"], url = "https://www.curseforge.com/wow/addons/manners" },
	{ key = "github", name = L["GitHub: bug reports and ideas"], url = "https://github.com/fpsacha/Manners/issues" },
}

local WIDTH, PAD, ROW = 480, 20, 62
local INNER = WIDTH - 2 * PAD
local window

-- A read-only box: what is typed is put back.
local function ReadOnly(box)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.fixed ~= nil then
			self:SetText(self.fixed)
			self:HighlightText()
		end
	end)
end

local function Copied(box)
	box.hint:Hide()
	box.copied:Show()
	box.copiedAt = (box.copiedAt or 0) + 1
	local mine = box.copiedAt
	if C_Timer and C_Timer.After then
		C_Timer.After(3, function()
			if box.copiedAt == mine then box.copied:Hide() end
		end)
	end
end

local function Build()
	local W = ns.WindowWidgets
	local T = W.Theme
	window = CreateFrame("Frame", "MannersLinks", UIParent)
	window:SetSize(WIDTH, 72 + #Links.LIST * ROW + 40)
	window:SetFrameStrata("DIALOG")
	if window.SetToplevel then window:SetToplevel(true) end
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	window:Hide()
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "MannersLinks") end
	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
	end)
	local body = W.Solid(window, "BACKGROUND", -6, { 0.04, 0.04, 0.06, 0.96 })
	body:SetAllPoints()
	W.Border(window, T.fieldEdge)

	local title = W.Text(window, T.fonts.large, T.gold)
	title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -14)
	title:SetText(L["Manners links"])
	local how = W.Wrapping(W.Text(window, T.fonts.small, T.hint))
	how:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -42)
	how:SetWidth(INNER)
	how:SetText(L["The game opens no browser: select a link, press Ctrl+C, and paste it in your browser."])

	window.boxes = {}
	for i, link in ipairs(Links.LIST) do
		local y = 72 + (i - 1) * ROW
		local label = W.Text(window, T.fonts.label, T.ink)
		label:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -y)
		label:SetText(link.name)
		local field = CreateFrame("Frame", nil, window)
		field:SetSize(INNER, 26)
		field:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(y + 22))
		W.Field(field)
		local box = CreateFrame("EditBox", nil, field)
		box:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
		box:SetSize(INNER, 26)
		box:SetAutoFocus(false)
		box:SetMaxLetters(0)
		W.SetFont(box, T.fonts.small)
		box:SetTextColor(T.inkSoft[1], T.inkSoft[2], T.inkSoft[3])
		box:SetTextInsets(8, 8, 6, 6)
		ReadOnly(box)
		box.fixed = link.url
		box:SetText(link.url)
		box:SetCursorPosition(0)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		box:SetScript("OnKeyDown", function(self, key)
			if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
				ns.Guard("links", Copied, self)
			end
		end)
		local select = W.Button(window, L["Select all"], function()
			box:SetFocus()
			box:HighlightText()
			box.copied:Hide()
			box.hint:Show()
		end)
		select:SetPoint("TOPRIGHT", window, "TOPLEFT", PAD + INNER, -y + 2)
		box.hint = W.Text(window, T.fonts.small, T.hint)
		box.hint:SetPoint("RIGHT", select, "LEFT", -8, 0)
		box.hint:SetText(L["Press Ctrl+C to copy."])
		box.hint:Hide()
		box.copied = W.Text(window, T.fonts.small, T.gold)
		box.copied:SetPoint("RIGHT", select, "LEFT", -8, 0)
		box.copied:SetText(L["Copied"])
		box.copied:Hide()
		box.select = select
		window.boxes[link.key] = box
	end

	local close = W.Button(window, L["Close"], function() window:Hide() end)
	close:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 14)
	window.close = close
end

function Links.Show()
	if not window then Build() end
	window:Show()
	if window.Raise then window:Raise() end
end

function Links.Window() return window end
