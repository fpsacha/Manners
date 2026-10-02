-- Manners -- options window: the frame's own parts around the page. The
-- header (icon and title, Show me the prompt, Snooze, the master switch, the
-- X), the status strip, the sidebar's page list and the footer.

local _, ns = ...
local L = ns.L
local UI = ns.WindowUI
local C = UI.C

-- The strip says the launcher's state line only for these: the states that
-- keep the prompt from doing what the player expects. Start here and Who to
-- buff say the rest in full (IA 1.3).
local STRIP_KINDS = { off = true, unlocked = true, snoozed = true, ownoff = true, blocked = true, mounted = true }

-- When to offer's combat line is about Hand my target back afterwards, so it
-- shows only while that is.
local COMBAT_NEEDS = { when = "advanced.restoreTarget" }

---------------------------------------------------------------------------
-- header: icon and title, Show me the prompt, Snooze, the switch, the X
---------------------------------------------------------------------------

local header = {}
UI.header = header

local function PreviewClicked()
	local item = header.previewItem
	if not item then return end
	local running = ns.Prompt and ns.Prompt:InTest()
	ns.WindowBind.Run(item)
	if running then UI.session.stoppedPreview = true end
end

-- The snooze menu, built from the layout's snooze entries, each by its own
-- rules: Stop snoozing is there only while a snooze runs.
local function FillSnooze(_, root)
	local B = ns.WindowBind
	local stop
	for _, item in ipairs(header.snoozeItems) do
		if not B.Hidden(item) then
			if item.key == "snoozeStop" then
				stop = item
			else
				root:CreateButton(B.Text(item, "name") or item.key, UI.Guarded(function() B.Run(item) end))
			end
		end
	end
	if stop then
		if root.CreateDivider then root:CreateDivider() end
		root:CreateButton(B.Text(stop, "name") or stop.key, UI.Guarded(function() B.Run(stop) end))
	end
end

local function SnoozeClicked(button)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(button, function(owner, root)
		ns.Guard("options snooze menu", FillSnooze, owner, root)
	end)
end

local function SnoozeTip(button)
	local item = header.snoozeTip
	local text = item and ns.WindowBind.Text(item, "name")
	if not text then return end
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(UI.Plain(header.snoozeLabel or L["Snooze"]), 1, 0.82, 0)
	GameTooltip:AddLine(text, 1, 1, 1, true)
	GameTooltip:Show()
end

function UI.BuildHeader(f)
	local W, layout = ns.WindowWidgets, UI.Layout().header
	local h = CreateFrame("Frame", nil, f)
	h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	h:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	h:SetHeight(UI.HEADER)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function() f:StartMoving() end)
	h:SetScript("OnDragStop", UI.Guarded(function() UI.Dropped() end))
	header.frame = h

	local band = h:CreateTexture(nil, "BACKGROUND")
	band:SetAllPoints()
	UI.Gradient(band, "VERTICAL", C.headBottom, C.headTop)
	local rule = UI.Solid(h, "BORDER", C.edge)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)

	local icon = h:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(UI.ICON)
	icon:SetSize(26, 26)
	icon:SetPoint("LEFT", h, "LEFT", 10, 0)
	-- The addon's name, which is not translated.
	local title = UI.Text(h, 16, C.gold)
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	title:SetText("Manners")

	-- The X hides this window, not the header it sits on.
	local close = CreateFrame("Button", nil, h, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("RIGHT", h, "RIGHT", -6, 0)
	close:SetScript("OnClick", function() f:Hide() end)
	header.close = close

	header.enabledItem = UI.Item(layout.enabled)
	if header.enabledItem then header.enabled = W.Build("toggle", h, header.enabledItem) end

	header.previewItem = UI.Item(layout.preview)
	header.preview = W.Button(h, L["Show me the prompt"], UI.Guarded(PreviewClicked))
	-- Hooked, so the button keeps whatever hover look the widgets give it.
	header.preview:HookScript("OnEnter", UI.Guarded(function() UI.HoverPreview(true) end))
	header.preview:HookScript("OnLeave", UI.Guarded(function() UI.HoverPreview(false) end))
	-- Sized once to the longer of its two labels, so it does not jump.
	header.previewWidth = math.ceil(math.max(UI.Measure(L["Show me the prompt"]), UI.Measure(L["Stop preview"]))) + 26

	header.snoozeItems = {}
	for _, path in ipairs(layout.snooze or {}) do
		local item = UI.Item(path)
		if item then header.snoozeItems[#header.snoozeItems + 1] = item end
	end
	header.snoozeTip = UI.Item(layout.snoozeTip)
	header.snooze = W.Button(h, L["Snooze"], UI.Guarded(SnoozeClicked))
	header.snooze:HookScript("OnEnter", UI.Guarded(SnoozeTip))
	header.snooze:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Placed from the right edge in: the X, the switch, Snooze, the preview.
function UI.PaintHeader()
	local B = ns.WindowBind
	local h, right = header.frame, UI.WIDTH - 6 - 24 - 10
	local switch = header.enabled
	if switch then
		local item = header.enabledItem
		local shown = not B.Hidden(item)
		switch.frame:SetShown(shown)
		if shown then
			switch.Refresh(switch)
			local w = math.min(260, math.ceil(switch.NaturalWidth(switch) or 160) + 4)
			local height = switch.Layout(switch, w) or 20
			switch.frame:ClearAllPoints()
			switch.frame:SetPoint("TOPLEFT", h, "TOPLEFT", right - w, -math.floor((UI.HEADER - height) / 2))
			switch.frame:SetSize(w, height)
			right = right - w - 12
		end
	end

	local anySnooze = false
	for _, item in ipairs(header.snoozeItems) do
		if not B.Hidden(item) then anySnooze = true end
	end
	local snooze = header.snooze
	snooze:SetShown(anySnooze)
	if anySnooze then
		local ends = ns.SnoozeEndsAt and ns.SnoozeEndsAt()
		header.snoozeLabel = ends and L["Snoozed until %s"]:format(ends) or L["Snooze"]
		UI.SetButtonText(snooze, header.snoozeLabel)
		local w = math.ceil(UI.Measure(header.snoozeLabel)) + 26
		snooze:SetSize(w, 22)
		snooze:ClearAllPoints()
		snooze:SetPoint("TOPLEFT", h, "TOPLEFT", right - w, -11)
		right = right - w - 10
	end

	local item, preview = header.previewItem, header.preview
	local shown = item ~= nil and not B.Hidden(item)
	preview:SetShown(shown)
	if shown then
		UI.SetButtonText(preview, B.Text(item, "name") or L["Show me the prompt"])
		preview:SetEnabled(not B.Disabled(item))
		preview:SetSize(header.previewWidth, 22)
		preview:ClearAllPoints()
		preview:SetPoint("TOPLEFT", h, "TOPLEFT", right - header.previewWidth, -11)
	end
end

---------------------------------------------------------------------------
-- status strip: the launcher's state line, Lock it, and the combat line
---------------------------------------------------------------------------

local strip = {}
UI.strip = strip

function UI.BuildStrip(f)
	local W = ns.WindowWidgets
	local s = CreateFrame("Frame", nil, f)
	s:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -UI.HEADER)
	s:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -UI.HEADER)
	s:SetHeight(1)
	local band = UI.Solid(s, "BACKGROUND", C.strip)
	band:SetAllPoints()
	local rule = UI.Solid(s, "BORDER", C.stripEdge)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)
	strip.frame = s
	strip.line1 = UI.Text(s, GameFontHighlight)
	strip.line2 = UI.Text(s, GameFontHighlight)
	strip.lockItem = UI.Item(UI.Layout().strip.lock)
	local lockName = strip.lockItem and ns.WindowBind.Text(strip.lockItem, "name") or L["Lock it"]
	strip.lock = W.Button(s, lockName, UI.Guarded(function()
		if strip.lockItem then ns.WindowBind.Run(strip.lockItem) end
	end))
	strip.lockWidth = math.ceil(UI.Measure(lockName)) + 26
	strip.height = 0
end

-- Line 1: the launcher's own line, for the states the player can act on.
local function StateLine()
	if not ns.LauncherState then return nil end
	local _, line, r, g, b, _, heldOnly, kind = ns.LauncherState()
	if type(line) ~= "string" or not (STRIP_KINDS[kind] or heldOnly) then return nil end
	return line, r or 1, g or 0.82, b or 0, kind
end

-- Line 2: in a fight, the open page's note on what waits for it to end.
local function CombatLine()
	if not InCombatLockdown() then return nil end
	local B = ns.WindowBind
	local item = UI.Item((UI.Layout().strip.combat or {})[UI.page])
	if not item or B.Hidden(item) then return nil end
	local needs = UI.Item(COMBAT_NEEDS[UI.page])
	if COMBAT_NEEDS[UI.page] and (not needs or B.Hidden(needs)) then return nil end
	local text = B.Text(item, "name")
	if not text then return nil end
	return (text:gsub("[\r\n%s]+$", ""))
end

-- Lays the strip out and answers its height: none at all when nothing needs
-- saying.
function UI.PaintStrip()
	local B = ns.WindowBind
	local s, width = strip, UI.WIDTH - 24
	local line, r, g, b, kind = StateLine()
	local lockShown = strip.lockItem ~= nil and not B.Hidden(strip.lockItem)
	strip.kind = line and kind or nil
	local combat = CombatLine()
	local y, height = 6, 0
	-- Lock it follows its own rule: there whenever the prompt is unlocked.
	s.lock:SetShown(lockShown)
	if line or lockShown then
		local room = width - (lockShown and (strip.lockWidth + 12) or 0)
		local lineH = 0
		if line then
			s.line1:SetWidth(room)
			s.line1:SetText(line)
			s.line1:SetTextColor(r, g, b, 1)
			s.line1:ClearAllPoints()
			s.line1:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 12, -y)
			s.line1:Show()
			lineH = UI.TextHeight(s.line1)
		else
			s.line1:Hide()
		end
		if lockShown then
			s.lock:SetSize(strip.lockWidth, 20)
			s.lock:ClearAllPoints()
			s.lock:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -12, -(y + math.max(0, (lineH - 20) / 2)))
			lineH = math.max(lineH, 20)
		end
		y = y + lineH + 3
	else
		s.line1:Hide()
	end
	if combat then
		s.line2:SetWidth(width)
		s.line2:SetText(combat)
		s.line2:SetTextColor(1, 0.82, 0, 1)
		s.line2:ClearAllPoints()
		s.line2:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 12, -y)
		s.line2:Show()
		y = y + UI.TextHeight(s.line2) + 3
	else
		s.line2:Hide()
	end
	strip.line, strip.combat = line, combat
	if line or combat or lockShown then height = math.ceil(y + 3) end
	s.frame:SetShown(height > 0)
	s.frame:SetHeight(math.max(height, 1))
	strip.height = height
	return height
end

---------------------------------------------------------------------------
-- sidebar: the search box, then the pages in their groups
---------------------------------------------------------------------------

-- Profiles' second line: the profile's name, cut to fit, with "Current
-- Profile: <name>" as its tooltip.
local function ProfileName()
	local db = ns.db
	if not (db and db.GetCurrentProfile) then return nil end
	local name = db:GetCurrentProfile()
	return type(name) == "string" and name or nil
end

local function PageTip(button)
	if button.id ~= "profiles" then return end
	local item = UI.Item("profiles.current")
	local text = item and ns.WindowBind.Text(item, "name")
	if not text then return end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(text, 1, 1, 1, true)
	GameTooltip:Show()
end

local function PageButton(id)
	local side = UI.side
	local b = CreateFrame("Button", nil, side.frame)
	b.id = id
	b:SetWidth(UI.SIDEBAR - 8)
	b.hover = UI.Solid(b, "BACKGROUND", C.hover)
	b.hover:SetAllPoints()
	b.hover:Hide()
	b.selected = UI.Solid(b, "BACKGROUND", C.select, 1)
	b.selected:SetAllPoints()
	b.bar = UI.Solid(b, "ARTWORK", C.gold)
	b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -4)
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 4)
	b.bar:SetWidth(3)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -5)
	b.name = UI.Text(b, GameFontNormal, C.nav)
	b.name:SetWidth(UI.SIDEBAR - 8 - 36 - 16)
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 36, -8)
	b.sub = UI.Text(b, GameFontDisableSmall, C.hint)
	b.sub:SetWidth(UI.SIDEBAR - 8 - 36 - 6)
	b.sub:SetWordWrap(false)
	b.dot = UI.Solid(b, "OVERLAY", C.dot)
	b.dot:SetSize(7, 7)
	b.dot:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -12)
	b:SetScript("OnClick", UI.Guarded(function() UI.ShowPage(id) end))
	b:SetScript("OnEnter", UI.Guarded(function(self)
		self.hover:Show()
		PageTip(self)
	end))
	b:SetScript("OnLeave", function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)
	side.buttons[id] = b
	return b
end

local function Hairline(parent)
	local t = UI.Solid(parent, "ARTWORK", C.line)
	t:SetHeight(1)
	return t
end

function UI.BuildSidebar()
	local side, layout = UI.side, UI.Layout()
	side.top = UI.BuildSearch(side.frame)
	side.lines = {}
	for gi, group in ipairs(layout.groups) do
		if gi > 1 then side.lines[gi] = Hairline(side.frame) end
		for _, id in ipairs(group) do PageButton(id) end
	end
end

-- Whether a page has anything for this character, and its red dot.
local function Warned(id)
	local warn = ns.OptionsPage.Warn
	local fn = type(warn) == "table" and warn[id]
	if type(fn) ~= "function" then return false end
	local ok, on = pcall(fn)
	if not ok then
		ns.Guard("options red dot " .. id, error, on, 0)
		return false
	end
	return on and true or false
end

local function PaintPageButton(b, page, y)
	local icon = page.icon
	if type(icon) == "function" then icon = icon() end
	b.icon:SetTexture(icon or UI.ICON)
	b.name:SetText(page.title or b.id)
	local selected = b.id == UI.page
	b.selected:SetShown(selected)
	b.bar:SetShown(selected)
	b.name:SetTextColor(selected and 1 or C.nav[1], selected and 1 or C.nav[2], selected and 1 or C.nav[3], 1)
	b.dot:SetShown(Warned(b.id))
	local height = math.max(20, UI.TextHeight(b.name)) + 10
	local profile = b.id == "profiles" and ProfileName() or nil
	if profile then
		b.sub:SetText(profile)
		b.sub:ClearAllPoints()
		b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
		b.sub:Show()
		height = height + UI.TextHeight(b.sub, 10)
	else
		b.sub:Hide()
	end
	b:SetHeight(height)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", UI.side.frame, "TOPLEFT", 4, -y)
	b:Show()
	return height
end

-- Pages with no control for this character leave the sidebar; a hairline
-- separates the groups that still have one.
function UI.PaintSidebar()
	local side, layout = UI.side, UI.Layout()
	local y, placed = side.top + 4, false
	UI.visiblePages = {}
	for gi, group in ipairs(layout.groups) do
		local line, any = side.lines[gi], false
		for _, id in ipairs(group) do
			local b, page = side.buttons[id], layout.pages[id]
			if page and UI.PageVisible(id) then
				if not any and placed and line then
					line:ClearAllPoints()
					line:SetPoint("TOPLEFT", side.frame, "TOPLEFT", 8, -(y + 5))
					line:SetPoint("TOPRIGHT", side.frame, "TOPRIGHT", -8, -(y + 5))
					line:Show()
					y = y + 11
				end
				any = true
				UI.visiblePages[id] = true
				y = y + PaintPageButton(b, page, y) + 1
			elseif b then
				b:Hide()
			end
		end
		if line and not (any and placed) then line:Hide() end
		placed = placed or any
	end
end

---------------------------------------------------------------------------
-- footer: the per-page reset, the build, Close
---------------------------------------------------------------------------

local footer = {}
UI.footer = footer

function UI.BuildFooter(f)
	local W, layout = ns.WindowWidgets, UI.Layout().footer
	local foot = CreateFrame("Frame", nil, f)
	foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	foot:SetHeight(UI.FOOTER)
	local rule = UI.Solid(foot, "BORDER", C.line)
	rule:SetPoint("TOPLEFT")
	rule:SetPoint("TOPRIGHT")
	rule:SetHeight(1)
	footer.frame = foot
	footer.resetItem = UI.Item(layout.reset)
	local label = footer.resetItem and ns.WindowBind.Text(footer.resetItem, "name") or ""
	footer.reset = W.Button(foot, label, UI.Guarded(function()
		if footer.resetItem then ns.WindowBind.Run(footer.resetItem) end
	end))
	footer.reset:SetSize(math.ceil(UI.Measure(label)) + 26, 22)
	footer.reset:SetPoint("LEFT", foot, "LEFT", 10, 0)
	footer.buildItem = UI.Item(layout.build)
	footer.build = UI.Text(foot, GameFontDisableSmall, C.hint)
	footer.build:SetJustifyH("CENTER")
	footer.build:SetPoint("CENTER", foot, "CENTER", 0, 0)
	local closeLabel = CLOSE or ""
	footer.close = W.Button(foot, closeLabel, function() f:Hide() end)
	footer.close:SetSize(math.max(80, math.ceil(UI.Measure(closeLabel)) + 26), 22)
	footer.close:SetPoint("RIGHT", foot, "RIGHT", -10, 0)
end

-- The reset's own hidden rule answers for the page in view (ns.OptionsTab).
function UI.PaintFooter()
	local B = ns.WindowBind
	local item = footer.resetItem
	footer.reset:SetShown(item ~= nil and not B.Hidden(item))
	if item then footer.reset:SetEnabled(not B.Disabled(item)) end
	local build = footer.buildItem and B.Text(footer.buildItem, "name")
	footer.build:SetText(build and UI.Plain(build) or "")
end
