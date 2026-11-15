-- Manners -- options window: the frame's own parts around the page. The
-- header (icon and title, Show me the prompt, Move the prompt, Snooze, the
-- master switch, the X), the status strip, the sidebar's page list and the footer.

local _, ns = ...
local L = ns.L
local UI = ns.WindowUI
local C = UI.C

-- The strip says the launcher's state line only for these: the states that
-- keep the prompt from doing what the player expects. Start here and Who to
-- buff say the rest in full. A place rule holding everybody back and the mana
-- floor (`placeheld`, `mana`) are among them: a prompt that stays empty in a
-- city is the one a player without a key has no other way to ask about.
local STRIP_KINDS = { off = true, broken = true, unlocked = true, snoozed = true, ownoff = true, blocked = true, mounted = true,
	plates = true, placeheld = true, mana = true }

-- The friendly nameplates off (the launcher's `plates`): the strip carries
-- the same button as Start here and Who to buff, which say it themselves with
-- that button under their passers-by, so the strip leaves those two pages be.
local PLATES_BUTTON = "general.startShowPlates"
local PLATES_SAID_ON = { general = true, who = true }

-- When to offer's combat line is about Hand my target back afterwards, so it
-- shows only while that is on screen, the Targeting fold open.
local COMBAT_NEEDS = { when = "advanced.restoreTarget" }

-- Snooze's chevron, saying it opens a menu: the dropdowns' own arrow, with 6
-- between it and the words.
local CHEVRON, CHEVRON_ROOM = 12, 16

---------------------------------------------------------------------------
-- header: icon and title, Show me the prompt, Move the prompt, Snooze, the
-- switch, the X
---------------------------------------------------------------------------

local header = {}
UI.header = header

local function PreviewClicked()
	local item = header.previewItem
	if not item then return end
	local running = ns.Prompt and ns.Prompt:InTest()
	ns.WindowBind.Run(item)
	if running then UI.session.stoppedPreview = true end
	-- Still resting on it: the 0.4 s counts again from the click, so a
	-- preview just started gets its peek without the pointer moving.
	if header.preview:IsMouseOver() then UI.HoverPreview(true) end
end

-- Move the prompt, which reads Lock it while the prompt is unlocked: the
-- model's button (general.moveToggle) run as the window runs any, so it goes
-- the way /manners unlock and lock go.
local function MoveClicked()
	local item = header.moveItem
	if item then ns.WindowBind.Run(item) end
end

-- The button's name in gold and its tooltip under it: what it does now, and in
-- a fight why it cannot.
local function MoveTip(button)
	local item = header.moveItem
	if not item then return end
	local B = ns.WindowBind
	local desc = B.Text(item, "desc")
	if not desc then return end
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(UI.Plain(B.Text(item, "name")), 1, 0.82, 0)
	GameTooltip:AddLine(desc, 1, 1, 1, true)
	GameTooltip:Show()
end

-- A menu entry's work. It answers nothing: the menu takes anything a
-- callback returns as its response, and only none (or CloseAll) shuts it, so
-- the guard's `true` left the menu open on stale entries.
local function Entry(item)
	return function() ns.Guard("options snooze", ns.WindowBind.Run, item) end
end

-- The snooze menu, built from the layout's snooze entries, each by its own
-- rules: Stop snoozing is there only while a snooze runs.
local function FillSnooze(_, root)
	local B = ns.WindowBind
	local stop
	for _, item in ipairs(header.snoozeItems) do
		if not UI.Hidden(item) then
			if item.key == "snoozeStop" then
				stop = item
			else
				root:CreateButton(B.Text(item, "name") or item.key, Entry(item))
			end
		end
	end
	if stop then
		if root.CreateDivider then root:CreateDivider() end
		root:CreateButton(B.Text(stop, "name") or stop.key, Entry(stop))
	end
end

local function SnoozeClicked(button)
	-- With a gamepad switched on there is no menu (ns.GamepadActive): the button
	-- stops a snooze that runs, and starts the fifteen minutes' otherwise.
	if ns.GamepadActive() then
		local B, start = ns.WindowBind, nil
		for _, item in ipairs(header.snoozeItems) do
			if not UI.Hidden(item) then
				if item.key == "snoozeStop" then
					ns.Guard("options snooze", B.Run, item)
					return
				end
				if item.key == "snooze15" or start == nil then start = item end
			end
		end
		if start then ns.Guard("options snooze", B.Run, start) end
		return
	end
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
	UI.Dress.Header(h, title)

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

	header.moveItem = UI.Item(layout.move)
	header.move = W.Button(h, L["Move the prompt"], UI.Guarded(MoveClicked))
	-- Greyed out in a fight, which is when its tooltip says why.
	W.TipsWhileOff(header.move)
	header.move:HookScript("OnEnter", UI.Guarded(MoveTip))
	header.move:HookScript("OnLeave", function() GameTooltip:Hide() end)
	-- The same: the longer of Move the prompt and Lock it.
	header.moveWidth = math.ceil(math.max(UI.Measure(L["Move the prompt"]), UI.Measure(L["Lock it"]))) + 26

	header.snoozeItems = {}
	for _, path in ipairs(layout.snooze or {}) do
		local item = UI.Item(path)
		if item then header.snoozeItems[#header.snoozeItems + 1] = item end
	end
	header.snoozeTip = UI.Item(layout.snoozeTip)
	local snooze = W.Button(h, L["Snooze"], UI.Guarded(SnoozeClicked))
	snooze:HookScript("OnEnter", UI.Guarded(SnoozeTip))
	snooze:HookScript("OnLeave", function() GameTooltip:Hide() end)
	snooze.chevron = snooze:CreateTexture(nil, "ARTWORK")
	snooze.chevron:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	snooze.chevron:SetSize(CHEVRON, CHEVRON)
	snooze.chevron:SetPoint("RIGHT", snooze, "RIGHT", -11, -2)
	snooze.chevron:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	-- The words centred in what the chevron leaves.
	if snooze.label then
		snooze.label:ClearAllPoints()
		snooze.label:SetPoint("CENTER", snooze, "CENTER", -CHEVRON_ROOM / 2, 0)
	end
	header.snooze = snooze
end

-- Placed from the right edge in: the X, the switch, Snooze, Move the prompt,
-- the preview.
function UI.PaintHeader()
	local B = ns.WindowBind
	local h, right = header.frame, UI.WIDTH - 6 - 24 - 10
	local switch = header.enabled
	if switch then
		local item = header.enabledItem
		local shown = not UI.Hidden(item)
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
		if not UI.Hidden(item) then anySnooze = true end
	end
	local snooze = header.snooze
	snooze:SetShown(anySnooze)
	if anySnooze then
		local ends = ns.SnoozeEndsAt and ns.SnoozeEndsAt()
		header.snoozeLabel = ends and L["Snoozed until %s"]:format(ends) or L["Snooze"]
		UI.SetButtonText(snooze, header.snoozeLabel)
		local w = math.ceil(UI.Measure(header.snoozeLabel)) + 26 + CHEVRON_ROOM
		snooze:SetSize(w, 22)
		snooze:ClearAllPoints()
		snooze:SetPoint("TOPLEFT", h, "TOPLEFT", right - w, -11)
		right = right - w - 10
	end

	local moveItem, move = header.moveItem, header.move
	local moveShown = moveItem ~= nil and not UI.Hidden(moveItem)
	move:SetShown(moveShown)
	if moveShown then
		UI.SetButtonText(move, B.Text(moveItem, "name") or L["Move the prompt"])
		move:SetEnabled(not UI.Disabled(moveItem))
		move:SetSize(header.moveWidth, 22)
		move:ClearAllPoints()
		move:SetPoint("TOPLEFT", h, "TOPLEFT", right - header.moveWidth, -11)
		right = right - header.moveWidth - 10
	end

	local item, preview = header.previewItem, header.preview
	local shown = item ~= nil and not UI.Hidden(item)
	preview:SetShown(shown)
	if shown then
		UI.SetButtonText(preview, B.Text(item, "name") or L["Show me the prompt"])
		preview:SetEnabled(not UI.Disabled(item))
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
	-- Wrapped inside a word too, for a language with no spaces to break at.
	for _, line in ipairs({ strip.line1, strip.line2 }) do
		line:SetWordWrap(true)
		if line.SetNonSpaceWrap then line:SetNonSpaceWrap(true) end
	end
	strip.lockItem = UI.Item(UI.Layout().strip.lock)
	local lockName = strip.lockItem and ns.WindowBind.Text(strip.lockItem, "name") or L["Lock it"]
	strip.lock = W.Button(s, lockName, UI.Guarded(function()
		if strip.lockItem then ns.WindowBind.Run(strip.lockItem) end
	end))
	strip.lockWidth = math.ceil(UI.Measure(lockName)) + 26
	-- Show friendly nameplates, beside the line that says they are off: Start
	-- here's own button run from here, so the click and its fight rule are one.
	strip.platesItem = UI.Item(PLATES_BUTTON)
	local platesName = strip.platesItem and ns.WindowBind.Text(strip.platesItem, "name") or L["Show friendly nameplates"]
	strip.plates = W.Button(s, platesName, UI.Guarded(function()
		if strip.platesItem and not UI.Disabled(strip.platesItem) then ns.WindowBind.Run(strip.platesItem) end
	end))
	strip.platesWidth = math.ceil(UI.Measure(platesName)) + 26
	strip.height = 0
end

-- Line 1: the launcher's own line, for the states the player can act on.
local function StateLine()
	if not ns.LauncherState then return nil end
	local _, line, r, g, b, _, heldOnly, kind = ns.LauncherState()
	if type(line) ~= "string" or not (STRIP_KINDS[kind] or heldOnly) then return nil end
	if kind == "plates" and PLATES_SAID_ON[UI.page] then return nil end
	return line, r or 1, g or 0.82, b or 0, kind
end

-- Whether the control a combat line is about is on screen: shown by its own
-- rules, on the short list while the simple view is on, and its fold open,
-- so the line never speaks of something shut away.
local function NeedShown(path)
	local needs = UI.Item(path)
	if not needs or UI.Hidden(needs) then return false end
	if UI.HiddenBySimple(path) then return false end
	local w = UI.Where(path)
	-- In the sub-division in view too, where a fold is drawn open.
	return not w or UI.SectionOpen(w.sec)
end

-- Line 2: in a fight, the open page's note on what waits for it to end.
local function CombatLine()
	if not InCombatLockdown() then return nil end
	local B = ns.WindowBind
	local item = UI.Item((UI.Layout().strip.combat or {})[UI.page])
	if not item or UI.Hidden(item) then return nil end
	if COMBAT_NEEDS[UI.page] and not NeedShown(COMBAT_NEEDS[UI.page]) then return nil end
	local text = B.Text(item, "name")
	if not text then return nil end
	-- Not %s, which under a Western locale takes the last byte of "加".
	return (text:gsub("[ \t\r\n]+$", ""))
end

-- Lays the strip out and answers its height: none at all when nothing needs
-- saying.
function UI.PaintStrip()
	local s, width = strip, UI.WIDTH - 24
	local line, r, g, b, kind = StateLine()
	local lockShown = strip.lockItem ~= nil and not UI.Hidden(strip.lockItem)
	strip.kind = line and kind or nil
	local combat = CombatLine()
	local y, height = 6, 0
	-- Lock it follows its own rule: there whenever the prompt is unlocked.
	s.lock:SetShown(lockShown)
	-- Show friendly nameplates goes with its line, by the button's own rule,
	-- greyed in a fight as the client refuses the setting there. Never beside
	-- Lock it: an unlocked prompt is the line then.
	local platesShown = not lockShown and strip.kind == "plates" and strip.platesItem ~= nil
		and not UI.Hidden(strip.platesItem)
	s.plates:SetShown(platesShown)
	if platesShown and s.plates.SetEnabled then s.plates:SetEnabled(not UI.Disabled(strip.platesItem)) end
	-- The one button the row holds, on its right.
	local side = lockShown and s.lock or platesShown and s.plates or nil
	local sideWidth = lockShown and strip.lockWidth or platesShown and strip.platesWidth or 0
	if line or side then
		local room = width - (side and (sideWidth + 12) or 0)
		local lineH = 0
		if line then
			s.line1:SetWidth(room)
			s.line1:SetText(line)
			s.line1:SetTextColor(r, g, b, 1)
			lineH = UI.TextHeight(s.line1)
			-- One row with Lock it, as the mock-up has it: a line shorter
			-- than the button sits level with its middle.
			local drop = side and math.max(0, math.floor((20 - lineH) / 2)) or 0
			s.line1:ClearAllPoints()
			s.line1:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 12, -(y + drop))
			s.line1:Show()
		else
			s.line1:Hide()
		end
		if side then
			side:SetSize(sideWidth, 20)
			side:ClearAllPoints()
			side:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -12, -(y + math.max(0, (lineH - 20) / 2)))
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
	if line or combat or side then height = math.ceil(y + 3) end
	s.frame:SetShown(height > 0)
	s.frame:SetHeight(math.max(height, 1))
	strip.height = height
	return height
end

---------------------------------------------------------------------------
-- the sub-divisions bar: the open page's second level (Layout.lua,
-- `subpages`), pinned over the page so it never scrolls away. Under the
-- strip and beside the sidebar; none for a page without sub-divisions.
---------------------------------------------------------------------------

local subbar = { chips = {} }
UI.subbar = subbar
-- A chip's height and padding, the gaps between chips and rows, and the
-- bar's margin: its first chip in line with the page's own left edge.
local CHIP_H, CHIP_PAD, CHIP_GAP, ROW_GAP, BAR_PAD, BAR_LEFT = 20, 10, 6, 2, 4, 18
local WHITE = { 1, 1, 1 }

function UI.BuildSubBar(f)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetHeight(1)
	local band = UI.Solid(bar, "BACKGROUND", C.side)
	band:SetAllPoints()
	local rule = UI.Solid(bar, "BORDER", C.line)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)
	-- The wheel over the bar scrolls the page under it, as over the page.
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", UI.Guarded(function(_, delta) UI.ScrollBy(-(delta or 0) * 48) end))
	bar:Hide()
	subbar.frame = bar
	subbar.height = 0
end

-- A chip, made the first time the bar needs one more. `key` nil is All.
local function Chip(i)
	local b = CreateFrame("Button", nil, subbar.frame)
	b:SetHeight(CHIP_H)
	b.hover = UI.Solid(b, "BACKGROUND", C.hover)
	b.hover:SetAllPoints()
	b.hover:Hide()
	b.selected = UI.Solid(b, "BACKGROUND", C.select, 1)
	b.selected:SetAllPoints()
	-- The one in view: a gold line under it, as the open page's gold bar.
	b.mark = UI.Solid(b, "ARTWORK", C.gold)
	b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.mark:SetHeight(2)
	b.label = UI.Text(b, GameFontHighlightSmall, C.nav)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetWordWrap(false)
	b.dot = UI.Dot(b, C.dot)
	b.dot:SetPoint("CENTER", b, "TOPRIGHT", -3, -4)
	b:SetScript("OnClick", UI.Guarded(function(self) UI.ShowSub(self.page, self.key) end))
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	subbar.chips[i] = b
	return b
end

-- Which sub-divisions hold a warning shown now: Page.WarnAt's, each where the
-- layout places the note that says it, while the page has its red dot.
local function SubWarnings(id)
	local out = {}
	local at = ns.OptionsPage.WarnAt
	if type(at) ~= "table" or not UI.PageWarned(id) then return out end
	for path, fn in pairs(at) do
		local w = UI.Where(path)
		if w and w.page == id and w.sec.sub then
			local ok, on = pcall(fn)
			if not ok then
				ns.Guard("options red dot " .. path, error, on, 0)
			elseif on then
				out[w.sec.sub] = true
			end
		end
	end
	return out
end

-- What the bar shows, in one string: the page, the sub-divisions listed and
-- the one in view. A paint of the page that changes it paints the bar again.
local function Signature(id)
	local current = UI.SubInView(id)
	local s = tostring(id) .. ":" .. tostring(current and current.key)
	for _, sub in ipairs(UI.SubsShown(id)) do s = s .. "," .. sub.key end
	return s
end

function UI.SubsStale()
	return subbar.sig ~= Signature(UI.page)
end

-- One chip at x, y: its label, marked when it is in view. Answers its width.
local function PaintChip(b, label, selected, warned, x, y)
	b.label:SetText(label)
	local c = selected and WHITE or C.nav
	b.label:SetTextColor(c[1], c[2], c[3], 1)
	local w = math.ceil(UI.TextWidth(b.label, 10)) + 2 * CHIP_PAD
	b:SetWidth(w)
	b.selected:SetShown(selected)
	b.mark:SetShown(selected)
	b.dot:SetShown(warned)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", subbar.frame, "TOPLEFT", x, -y)
	b:Show()
	return w
end

-- Lays the bar out at the top of the content area, `top` down the window:
-- All, then each sub-division with something to show, left to right and onto
-- another row where the width runs out. Answers its height, 0 when hidden.
function UI.PaintSubBar(top)
	local bar, id = subbar.frame, UI.page
	local subs = id and UI.SubsShown(id) or {}
	subbar.sig = Signature(id)
	local used, height = 0, 0
	if #subs > 0 then
		local current, warned = UI.SubInView(id), SubWarnings(id)
		local right = UI.WIDTH - UI.SIDEBAR - 1 - 12 - BAR_PAD
		local x, y = BAR_LEFT, BAR_PAD
		local function Add(key, label, selected, dot)
			used = used + 1
			local b = subbar.chips[used] or Chip(used)
			b.page, b.key = id, key
			local w = PaintChip(b, label, selected, dot, x, y)
			-- Too wide for what is left of the row: the next row.
			if x > BAR_LEFT and x + w > right then
				x, y = BAR_LEFT, y + CHIP_H + ROW_GAP
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
			end
			x = x + w + CHIP_GAP
		end
		Add(nil, L["All"], current == nil, false)
		for _, sub in ipairs(subs) do
			Add(sub.key, UI.Plain(UI.SubLabel(sub)), current == sub, warned[sub] == true)
		end
		height = y + CHIP_H + BAR_PAD + 1
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", UI.SIDEBAR + 1, -top)
		bar:SetPoint("TOPRIGHT", UI.frame, "TOPRIGHT", -12, -top)
		bar:SetHeight(height)
	end
	bar:SetShown(height > 0)
	for k = used + 1, #subbar.chips do subbar.chips[k]:Hide() end
	subbar.height = height
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
	UI.Dress.PageButton(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -5)
	b.name = UI.Text(b, GameFontNormal, C.nav)
	b.name:SetWidth(UI.SIDEBAR - 8 - 36 - 16)
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 36, -8)
	b.sub = UI.Text(b, GameFontDisableSmall, C.hint)
	b.sub:SetWidth(UI.SIDEBAR - 8 - 36 - 6)
	b.sub:SetWordWrap(false)
	b.dot = UI.Dot(b, C.dot)
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
	-- The simple view's switch, under the search box on every page (Layout.lua,
	-- `menu`): the model's control, drawn and run as the window runs any.
	side.viewItem = UI.Item((layout.menu or {}).simple)
	if side.viewItem then side.view = ns.WindowWidgets.Build("toggle", side.frame, side.viewItem) end
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
UI.PageWarned = Warned

local function PaintPageButton(b, page, y)
	local icon = page.icon
	if type(icon) == "function" then icon = icon() end
	b.icon:SetTexture(icon or UI.ICON)
	b.name:SetText(page.title or b.id)
	local selected = b.id == UI.page
	b.selected:SetShown(selected)
	b.bar:SetShown(selected)
	UI.Dress.PageSelected(b, selected)
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

-- The simple view's switch under the search box, read again and laid out at
-- the sidebar's width; answers the room it takes, none while its rule hides it.
local function PaintView(side)
	local row, item = side.view, side.viewItem
	if not row then return 0 end
	local shown = not UI.Hidden(item)
	row.frame:SetShown(shown)
	if not shown then return 0 end
	row.Refresh(row)
	local width = UI.SIDEBAR - 20
	local height = row.Layout(row, width) or 20
	row.frame:ClearAllPoints()
	row.frame:SetPoint("TOPLEFT", side.frame, "TOPLEFT", 10, -(side.top + 2))
	row.frame:SetSize(width, height)
	return height + 8
end

-- Pages with no control for this character leave the sidebar; a hairline
-- separates the groups that still have one.
function UI.PaintSidebar()
	local side, layout = UI.side, UI.Layout()
	local y, placed = side.top + PaintView(side) + 4, false
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
-- footer: the per-page reset, who makes Manners, the build at the right, Close
---------------------------------------------------------------------------

local footer = {}
UI.footer = footer
-- Between a button and what stands in the middle; the size who makes Manners
-- is written at (the author asked for it larger and easier to see than the
-- hint it was, 1.11.25); the smallest it is set to fit.
local FOOT_GAP, FOOT_ABOUT, FOOT_SMALLEST = 8, 13, 7

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
	UI.Dress.Footer(foot)
	footer.frame = foot
	footer.resetItem = UI.Item(layout.reset)
	local label = footer.resetItem and ns.WindowBind.Text(footer.resetItem, "name") or ""
	footer.reset = W.Button(foot, label, UI.Guarded(function()
		if footer.resetItem then ns.WindowBind.Run(footer.resetItem) end
	end))
	footer.reset:SetSize(math.ceil(UI.Measure(label)) + 26, 22)
	footer.reset:SetPoint("LEFT", foot, "LEFT", 10, 0)
	footer.buildItem = UI.Item(layout.build)
	local closeLabel = CLOSE or ""
	footer.close = W.Button(foot, closeLabel, function() f:Hide() end)
	footer.close:SetSize(math.max(80, math.ceil(UI.Measure(closeLabel)) + 26), 22)
	-- Clear of the resize grip in the corner (Window.lua, BuildGrip).
	footer.close:SetPoint("RIGHT", foot, "RIGHT", -24, 0)
	-- Between the two buttons, on every page: who makes Manners, in the
	-- window's own ink at a size to be read, in the middle of the room; and
	-- the build, small and grey, at the right beside Close.
	local mid = CreateFrame("Frame", nil, foot)
	mid:SetPoint("TOPLEFT", footer.reset, "TOPRIGHT", FOOT_GAP, 0)
	mid:SetPoint("BOTTOMRIGHT", footer.close, "BOTTOMLEFT", -FOOT_GAP, 0)
	footer.mid = mid
	footer.build = UI.Text(mid, GameFontDisableSmall, C.hint)
	footer.build:SetJustifyH("RIGHT")
	footer.aboutItem = UI.Item(layout.about)
	footer.about = UI.Text(mid, FOOT_ABOUT, C.ink)
	footer.about:SetJustifyH("CENTER")
	if footer.about.SetWordWrap then footer.about:SetWordWrap(false) end
	footer.aboutFont = { footer.about:GetFont() }
	-- The line is a way to reach the author, where the character it names can
	-- be reached: on WoW Forever only. A left click opens a whisper to them in
	-- the chat box (nothing is sent: the player writes and sends it), a right
	-- click looks them up with /who. It asks for nothing, as the line itself
	-- never does (tests/scenarios/about.lua).
	if ns.Flavour and ns.Flavour.flavour == "camelot" then
		local hit = CreateFrame("Button", nil, mid)
		-- Over the name alone, placed in PaintFooter from the widths of the
		-- words before it and of the name: a font string cannot say where one
		-- of its words is. `measure` is never shown.
		footer.measure = UI.Text(mid, FOOT_ABOUT, C.ink)
		footer.measure:Hide()
		hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		hit:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(tostring(ns.AUTHOR), C.gold[1], C.gold[2], C.gold[3])
			GameTooltip:AddLine(L["Click to whisper."], 1, 1, 1)
			GameTooltip:AddLine(L["Right-click to look them up."], 1, 1, 1)
			GameTooltip:Show()
		end)
		hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
		hit:SetScript("OnClick", UI.Guarded(function(_, button) UI.AuthorClicked(button) end))
		footer.aboutHit = hit
	end
end

-- What a click on the footer's line does (see BuildFooter). The whisper goes
-- through the game's own chat box; the look-up through its /who.
function UI.AuthorClicked(button)
	local name = ns.AUTHOR
	if type(name) ~= "string" or name == "" then return end
	if button == "RightButton" then
		local who = C_FriendList and C_FriendList.SendWho or _G.SendWho
		if type(who) == "function" then who('n-"' .. name .. '"') end
		return
	end
	local open = _G.ChatFrame_OpenChat
	if type(open) == "function" then open("/w " .. name .. " ") end
end

-- How wide the build stands at the right of the footer, its gap included; 0
-- with no build written.
local function BuildRoom()
	local text = footer.build and footer.build:GetText()
	if not text or text == "" then return 0 end
	local _, size = footer.build:GetFont()
	return math.ceil(UI.TextWidth(footer.build, size or 10)) + FOOT_GAP
end

-- The room who makes Manners has: between the footer's buttons, whatever their
-- labels' language, less the build at the right.
function UI.FooterRoom()
	local reset, close = footer.reset:GetWidth() or 0, footer.close:GetWidth() or 0
	return UI.WIDTH - 34 - reset - close - 2 * FOOT_GAP - BuildRoom()
end

-- The reset's own hidden rule answers for the page in view (ns.OptionsTab),
-- and its tab's does not: Advanced is hidden for a class with no prompt (a
-- rogue), whose What I say still has a reset.
function UI.PaintFooter()
	local B = ns.WindowBind
	local item = footer.resetItem
	footer.reset:SetShown(item ~= nil and not UI.OwnHidden(item))
	if item then footer.reset:SetEnabled(not UI.Disabled(item)) end
	local build = footer.buildItem and B.Text(footer.buildItem, "name")
	footer.build:SetText(build and UI.Plain(build) or "")
	-- The build at the right, beside Close.
	footer.build:ClearAllPoints()
	footer.build:SetPoint("RIGHT", footer.mid, "RIGHT", 0, 0)
	-- Who makes Manners, the name in gold as the line gives it. One line: a
	-- language that needs more than the room is set smaller, never cut short.
	local about = footer.aboutItem and B.Text(footer.aboutItem, "name") or ""
	local fs, font = footer.about, footer.aboutFont
	local room = UI.FooterRoom()
	if about ~= footer.aboutText or room ~= footer.aboutRoom then
		footer.aboutText, footer.aboutRoom = about, room
		local path, size, flags = font[1] or UI.FontPath(), font[2] or FOOT_ABOUT, font[3] or ""
		if path then fs:SetFont(path, size, flags) end
		fs:SetText(about)
		local wide = UI.TextWidth(fs, size)
		if path and wide > room then
			fs:SetFont(path, math.max(FOOT_SMALLEST, math.floor(size * room / wide)), flags)
		end
	end
	-- In the middle of the room the build leaves, on the footer's own line.
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", footer.mid, "CENTER", -BuildRoom() / 2, 0)
	fs:SetShown(about ~= "")
	-- The click area, over the author's name where the line has it.
	local hit = footer.aboutHit
	if hit then
		local plainLine, name = UI.Plain(about), tostring(ns.AUTHOR or "")
		local at = name ~= "" and plainLine:find(name, 1, true) or nil
		if at then
			local m = footer.measure
			local path, size, flags = fs:GetFont()
			if path then m:SetFont(path, size, flags or "") end
			m:SetText(plainLine:sub(1, at - 1))
			local before = at > 1 and UI.TextWidth(m, size) or 0
			m:SetText(name)
			local wide = UI.TextWidth(m, size)
			hit:ClearAllPoints()
			hit:SetPoint("LEFT", fs, "LEFT", before, 0)
			hit:SetSize(math.max(1, wide), (size or FOOT_ABOUT) + 6)
		end
		hit:SetShown(at ~= nil)
	end
end
