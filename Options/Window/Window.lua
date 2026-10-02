-- Manners -- options window: the frame (MannersOptions), its state, opening
-- and shutting it, the scrolling content area, the preview and the peek.
--
-- The header, strip, sidebar and footer are WindowChrome.lua's, the pages
-- WindowPage.lua's and the search box WindowSearch.lua's; they share this
-- table. Everything here is plain frames, so the window opens, moves and
-- shuts in a fight like any other.

local _, ns = ...

local UI = {}
ns.WindowUI = UI

-- At UI scale 1 a 1280x720 screen is 1365 x 768 units, which leaves room
-- above and below; inside, the header, footer and sidebar are fixed and the
-- content scrolls.
UI.WIDTH, UI.HEIGHT = 820, 600
UI.HEADER, UI.FOOTER, UI.SIDEBAR = 44, 34, 160
UI.ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- The window's own colours, from the approved mock-up: a dark panel, gold
-- headings over a thin gold rule, off-white labels, grey hints, red warnings.
local C = {
	win = { 0.059, 0.059, 0.075, 0.97 },
	headTop = { 0.118, 0.110, 0.133, 1 },
	headBottom = { 0.071, 0.067, 0.086, 1 },
	side = { 0.078, 0.078, 0.094, 1 },
	content = { 0.051, 0.051, 0.067, 1 },
	edge = { 0.302, 0.255, 0.173, 1 },
	line = { 1, 1, 1, 0.09 },
	faint = { 1, 1, 1, 0.05 },
	gold = { 1, 0.82, 0, 1 },
	goldSoft = { 0.902, 0.769, 0.369, 1 },
	goldRule = { 1, 0.82, 0, 0.42 },
	ink = { 0.922, 0.902, 0.855, 1 },
	nav = { 0.910, 0.843, 0.639, 1 },
	hint = { 0.557, 0.545, 0.518, 1 },
	red = { 1, 0.5, 0.5, 1 },
	dot = { 1, 0.29, 0.227, 1 },
	strip = { 1, 0.82, 0, 0.055 },
	stripEdge = { 1, 0.82, 0, 0.18 },
	select = { 1, 0.82, 0, 0.09 },
	hover = { 1, 1, 1, 0.09 },
	field = { 0.024, 0.024, 0.031, 1 },
	fieldEdge = { 0.239, 0.235, 0.271, 1 },
}
UI.C = C

---------------------------------------------------------------------------
-- small drawing helpers, shared with WindowPage.lua and WindowSearch.lua
---------------------------------------------------------------------------

function UI.Solid(parent, layer, colour, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
	return t
end

-- SetGradient changed shape between client generations; tried as Prompt.lua
-- tries it, over a white texture for the colours to tint, with a flat colour
-- that always works behind it. Vertical runs bottom to top.
function UI.Gradient(tex, orientation, from, to)
	tex:SetTexture("Interface\\Buttons\\WHITE8X8")
	if tex.SetGradient and CreateColor then
		local ok = pcall(tex.SetGradient, tex, orientation,
			CreateColor(from[1], from[2], from[3], from[4] or 1), CreateColor(to[1], to[2], to[3], to[4] or 1))
		if ok then return end
	end
	tex:SetVertexColor(to[1], to[2], to[3], to[4] or 1)
end

-- Friz Quadrata in Latin clients, and whatever the client's own normal font is
-- elsewhere: a Korean or Chinese client's Friz has no glyphs for its language.
function UI.FontPath()
	local font = GameFontNormal
	if font and font.GetFont then
		local path = font:GetFont()
		if type(path) == "string" then return path end
	end
	return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- A FontString in a font object, or in the normal font at `size`, coloured.
function UI.Text(parent, font, colour, layer)
	local fs = parent:CreateFontString(nil, layer or "ARTWORK")
	if type(font) == "number" then
		fs:SetFont(UI.FontPath(), font, "")
	elseif font then
		fs:SetFontObject(font)
	end
	if colour then fs:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1) end
	fs:SetJustifyH("LEFT")
	return fs
end

-- How wide and how tall a string draws, or a guess when the client will not
-- say: half the font size a character, as the renderer's fallback does.
function UI.TextWidth(fs, fallbackSize)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	local w = measure and measure(fs)
	if type(w) == "number" and w > 0 then return w end
	local text = fs:GetText()
	return #tostring(text or "") * (fallbackSize or 12) * 0.55
end

function UI.TextHeight(fs, fallbackSize)
	local h = fs.GetStringHeight and fs:GetStringHeight()
	if type(h) == "number" and h > 0 then return h end
	return (fallbackSize or 12) + 2
end

-- A label's width in a font object, for buttons sized to the longer of two
-- labels. One hidden string does the measuring.
function UI.Measure(text, font)
	local fs = UI.measurer
	if not fs then
		fs = UI.frame:CreateFontString(nil, "ARTWORK")
		fs:Hide()
		UI.measurer = fs
	end
	fs:SetFontObject(font or GameFontNormal)
	fs:SetText(text or "")
	return UI.TextWidth(fs)
end

-- Colour codes and textures out, for text the window draws in a colour of its
-- own (the build line, a combat line's trailing break).
function UI.Plain(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A chrome button's label. W.Button keeps an explicit FontString; asked by
-- method first, so a widget set that renames the field still works.
function UI.SetButtonText(button, text)
	if button.SetLabel then
		button:SetLabel(text)
	elseif button.label then
		button.label:SetText(text)
	end
end

-- Each script handler's work goes through the addon's event-boundary guard.
function UI.Guarded(fn)
	return function(...) return ns.Guard("options window", fn, ...) end
end

---------------------------------------------------------------------------
-- state: ns.db.global.window, never the profile
---------------------------------------------------------------------------

-- Sharing, copying or switching a profile never moves the window or opens
-- and shuts its folds, so its state is account-wide. A table of its own when
-- the database has no global section (a stripped test client).
local loose = {}
function UI.State()
	local db = ns.db
	local global = type(db) == "table" and type(db.global) == "table" and db.global or nil
	local s
	if global then
		s = global.window
		if type(s) ~= "table" then
			s = {}
			global.window = s
		end
	else
		s = loose
	end
	if type(s.open) ~= "table" then s.open = {} end
	return s
end

-- What lasts only while the window is open: a preview stopped by hand.
UI.session = { stoppedPreview = false }

function UI.Layout() return ns.WindowLayout end

function UI.Item(path, entry)
	return path and ns.WindowBind.Item(path, entry, UI.ctx) or nil
end

---------------------------------------------------------------------------
-- the peek: the window fades so the real prompt behind it shows (IA 1.7)
---------------------------------------------------------------------------

local PEEK_ALPHA, FADE_OUT, FADE_IN, PEEK_AFTER, HOVER_DELAY = 0.25, 0.15, 0.2, 1.5, 0.4
local peek = { held = false, hover = false, untilAt = 0, alpha = 1, hoverToken = 0 }
UI.peek = peek

-- No peek in a fight: Look's changes wait for it to end anyway.
function UI.PeekTarget()
	if InCombatLockdown() then return 1 end
	if peek.held or peek.hover or GetTime() < peek.untilAt then return PEEK_ALPHA end
	return 1
end

function UI.EndPeek()
	peek.held, peek.hover, peek.untilAt = false, false, 0
	peek.hoverToken = peek.hoverToken + 1
	peek.alpha = 1
	if UI.frame then UI.frame:SetAlpha(1) end
end

-- Down to a quarter in 0.15 s, back in 0.2 s.
local function Fade(elapsed)
	local target = UI.PeekTarget()
	local alpha = peek.alpha
	if alpha == target then return end
	if alpha > target then
		alpha = math.max(target, alpha - (1 - PEEK_ALPHA) * elapsed / FADE_OUT)
	else
		alpha = math.min(target, alpha + (1 - PEEK_ALPHA) * elapsed / FADE_IN)
	end
	peek.alpha = alpha
	UI.frame:SetAlpha(alpha)
end

-- Whether a control is on Look, where a change shows on the prompt behind.
local function OnLook(item)
	return item ~= nil and UI.PageOf(item.path) == "appearance"
end

-- After any committed change: the peek for a change on Look, and a repaint
-- of everything the change can reach.
function UI.Changed(item)
	if OnLook(item) and not InCombatLockdown() then peek.untilAt = GetTime() + PEEK_AFTER end
	UI.Refresh()
end

-- A slider or nudge arrow held down, or the colour picker up, on Look.
function UI.Held(on)
	peek.held = on and UI.page == "appearance" and not InCombatLockdown() or false
end

-- The pointer resting on Show me the prompt while a preview runs.
function UI.HoverPreview(on)
	peek.hoverToken = peek.hoverToken + 1
	peek.hover = false
	if not on then return end
	local token = peek.hoverToken
	C_Timer.After(HOVER_DELAY, function()
		if token == peek.hoverToken and ns.Prompt and ns.Prompt:InTest() then peek.hover = true end
	end)
end

-- What the widgets are handed with every item.
UI.ctx = {
	OnChange = function(item) ns.Guard("options window", UI.Changed, item) end,
	OnHold = function(on) ns.Guard("options window", UI.Held, on) end,
	Repaint = function() ns.Guard("options repaint", UI.Refresh) end,
}

---------------------------------------------------------------------------
-- the preview (IA 1.7): the real prompt, started for the player twice
---------------------------------------------------------------------------

local function StartPreview()
	if InCombatLockdown() or not ns.Prompt or ns.Prompt:InTest() then return end
	if not ns.OptionsPage.HasPrompt() then return end
	ns.Prompt:ToggleTest()
end

-- Opening Look starts it, unless the player stopped it while the window was
-- open.
function UI.LookOpened()
	if not UI.session.stoppedPreview then StartPreview() end
end

---------------------------------------------------------------------------
-- body: the sidebar and the content area, under the strip
---------------------------------------------------------------------------

-- The top of the sidebar and the content follow the strip's height.
local function PlaceBody(top)
	local f = UI.frame
	local side, view = UI.side, UI.view
	side.frame:ClearAllPoints()
	side.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
	side.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, UI.FOOTER)
	side.frame:SetWidth(UI.SIDEBAR)
	view.scroll:ClearAllPoints()
	view.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", UI.SIDEBAR + 1, -top)
	view.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, UI.FOOTER)
	view.bar:ClearAllPoints()
	view.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -(top + 4))
	view.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, UI.FOOTER + 4)
	view.height = UI.HEIGHT - top - UI.FOOTER
	if UI.results then
		UI.results:ClearAllPoints()
		UI.results:SetPoint("TOPLEFT", f, "TOPLEFT", UI.SIDEBAR + 8, -(top + 4))
	end
end

local function BuildBody(f)
	local side = { buttons = {} }
	UI.side = side
	side.frame = CreateFrame("Frame", nil, f)
	local bg = UI.Solid(side.frame, "BACKGROUND", C.side)
	bg:SetAllPoints()
	local edge = UI.Solid(side.frame, "BORDER", C.line)
	edge:SetPoint("TOPRIGHT")
	edge:SetPoint("BOTTOMRIGHT")
	edge:SetWidth(1)

	local view = {}
	UI.view = view
	view.scroll = CreateFrame("ScrollFrame", nil, f)
	local back = UI.Solid(view.scroll, "BACKGROUND", C.content)
	back:SetAllPoints()
	view.scroll:EnableMouseWheel(true)
	view.scroll:SetScript("OnMouseWheel", UI.Guarded(function(_, delta) UI.ScrollBy(-(delta or 0) * 48) end))
	view.child = CreateFrame("Frame", nil, view.scroll)
	view.child:SetSize(UI.WIDTH - UI.SIDEBAR - 13, 1)
	view.scroll:SetScrollChild(view.child)

	-- A slim bar: a faint track and a gold thumb.
	view.bar = CreateFrame("Slider", nil, f)
	view.bar:SetOrientation("VERTICAL")
	view.bar:SetWidth(6)
	view.bar:SetMinMaxValues(0, 0)
	view.bar:SetValueStep(1)
	view.bar:SetObeyStepOnDrag(false)
	local track = UI.Solid(view.bar, "BACKGROUND", C.faint)
	track:SetAllPoints()
	view.thumb = view.bar:CreateTexture(nil, "ARTWORK")
	view.thumb:SetColorTexture(0.29, 0.25, 0.188, 1)
	view.thumb:SetSize(6, 40)
	view.bar:SetThumbTexture(view.thumb)
	view.bar:SetScript("OnValueChanged", UI.Guarded(function(_, value)
		if UI.settingBar then return end
		UI.ScrollTo(value)
	end))
	view.bar:EnableMouseWheel(true)
	view.bar:SetScript("OnMouseWheel", UI.Guarded(function(_, delta) UI.ScrollBy(-(delta or 0) * 48) end))
	view.scrollY, view.range, view.height = 0, 0, UI.HEIGHT - UI.HEADER - UI.FOOTER
	PlaceBody(UI.HEADER)
end

-- The scroll position, kept within what there is to scroll.
function UI.ScrollTo(y)
	local view = UI.view
	y = math.max(0, math.min(tonumber(y) or 0, view.range or 0))
	view.scrollY = y
	view.scroll:SetVerticalScroll(y)
	UI.settingBar = true
	view.bar:SetValue(y)
	UI.settingBar = false
end

function UI.ScrollBy(dy)
	UI.ScrollTo((UI.view.scrollY or 0) + dy)
end

-- After a page has been laid out: how far it scrolls, and the bar to match.
function UI.SetContentHeight(height)
	local view = UI.view
	view.child:SetHeight(math.max(height, view.height))
	view.range = math.max(0, height - view.height)
	view.scroll:UpdateScrollChildRect()
	UI.settingBar = true
	view.bar:SetMinMaxValues(0, view.range)
	UI.settingBar = false
	view.bar:SetShown(view.range > 0)
	if view.range > 0 then
		local track = view.height - 8
		view.thumb:SetHeight(math.max(24, math.floor(track * view.height / height)))
	end
	UI.ScrollTo(view.scrollY)
end

---------------------------------------------------------------------------
-- the frame
---------------------------------------------------------------------------

local function Place(f)
	local s = UI.State()
	f:ClearAllPoints()
	if type(s.point) == "string" and type(s.x) == "number" and type(s.y) == "number" then
		f:SetPoint(s.point, UIParent, type(s.relPoint) == "string" and s.relPoint or s.point, s.x, s.y)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- Kept in the window's own state only; left user-placed, the client's layout
-- cache would keep a second copy that can disagree.
function UI.Dropped()
	local f = UI.frame
	f:StopMovingOrSizing()
	f:SetUserPlaced(false)
	local point, _, relPoint, x, y = f:GetPoint()
	if type(point) == "string" and type(x) == "number" and type(y) == "number" then
		local s = UI.State()
		s.point, s.relPoint, s.x, s.y = point, relPoint or point, x, y
	end
end

local function Hidden()
	ns.OptionsPage.reportOpen = false
	ns.OptionsPage.shareOpen = false
	UI.session.stoppedPreview = false
	UI.EndPeek()
	if UI.CloseResults then UI.CloseResults() end
	GameTooltip:Hide()
end

function UI.Build()
	local f = CreateFrame("Frame", "MannersOptions", UIParent)
	UI.frame = f
	f:Hide()
	f:SetSize(UI.WIDTH, UI.HEIGHT)
	f:SetFrameStrata("HIGH")
	-- Comes to the front of its strata when clicked; the ledger does the
	-- same, so whichever was opened last is on top.
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	Place(f)
	-- Escape shuts it, like every other window of its kind.
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "MannersOptions") end
	UI.ctx.Window = f

	local body = UI.Solid(f, "BACKGROUND", C.win, -8)
	body:SetAllPoints()
	-- The border: four textures, no backdrop.
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
		local t = UI.Solid(f, "BORDER", C.edge, 2)
		t:SetPoint(side[1])
		t:SetPoint(side[2])
		if side[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
	end

	UI.BuildHeader(f)
	UI.BuildStrip(f)
	BuildBody(f)
	UI.BuildSidebar()
	UI.BuildFooter(f)
	f:SetScript("OnHide", UI.Guarded(Hidden))
	f:SetScript("OnUpdate", function(_, elapsed) Fade(elapsed or 0) end)
	-- Last: anything that throws above leaves no half-built window behind for
	-- tools and tests to find.
	ns.OptionsWindow = f
	UI.built = true
end

-- A page id that can be shown: the one asked for, the last one, Start here.
local function PageToOpen(id)
	local pages = UI.Layout().pages
	if id and pages[id] and UI.PageVisible(id) then return id end
	local last = UI.State().page
	if last and pages[last] and UI.PageVisible(last) then return last end
	return "general"
end

function UI.Open(pageId)
	if not UI.frame then UI.Build() end
	local f = UI.frame
	local was, wasShown = UI.page, f:IsShown()
	f:Show()
	f:Raise()
	local id = PageToOpen(pageId)
	UI.ShowPage(id)
	-- Opening the window onto Look is opening Look.
	if id == "appearance" and was == id and not wasShown then UI.LookOpened() end
	-- The very first time, out of a fight and with a prompt, the preview
	-- starts by itself once.
	local s = UI.State()
	if not s.previewShown and not InCombatLockdown() and ns.OptionsPage.HasPrompt() then
		s.previewShown = true
		StartPreview()
	end
end

function UI.Close()
	if UI.frame then UI.frame:Hide() end
end

function UI.Shown()
	return UI.built == true and UI.frame:IsShown() == true
end

-- The page in view: its rows built the first time, the others' rows put away.
function UI.ShowPage(id)
	if not UI.Layout().pages[id] then return end
	local was = UI.page
	if was and was ~= id then UI.HidePage(was) end
	UI.page = id
	UI.State().page = id
	if was ~= id then UI.view.scrollY = 0 end
	UI.Refresh()
	if id == "appearance" and was ~= id and UI.Shown() then UI.LookOpened() end
end

-- Everything on screen from the values as they stand. Re-entered from a
-- repaint a model function asks for while this one runs: that one is
-- dropped, since this one is reading the same values.
local function PaintAll()
	UI.PaintSidebar()
	-- The page in view lost its last control (a profile switched, a spell
	-- unlearned): the window moves to one that has some.
	if not (UI.visiblePages or {})[UI.page] then
		local to = PageToOpen(nil)
		if to ~= UI.page then
			if UI.page then UI.HidePage(UI.page) end
			UI.page = to
			UI.State().page = to
			UI.view.scrollY = 0
			UI.PaintSidebar()
		end
	end
	UI.PaintHeader()
	PlaceBody(UI.HEADER + UI.PaintStrip())
	UI.PaintPage()
	UI.PaintFooter()
end

function UI.Refresh()
	if not UI.built or UI.painting then return end
	UI.painting = true
	local ok, err = pcall(PaintAll)
	UI.painting = false
	if not ok then error(err, 0) end
end

-- After the spellbook changes (Core.lua probes it again on SPELLS_CHANGED,
-- learned spells included): rows for a spell just learned appear without a
-- /reload. Hooked here rather than registering events of our own.
do
	local probe = ns.ProbeCapabilities
	if type(probe) == "function" then
		ns.ProbeCapabilities = function(...)
			local caps = probe(...)
			if UI.Shown() then ns.Guard("options repaint", UI.Refresh) end
			return caps
		end
	end
end
