-- Manners -- options window: the frame (MannersOptions), its state, opening
-- and shutting it, the scrolling content area, the preview and the peek.
--
-- The header, strip, sidebar and footer are WindowChrome.lua's, the pages
-- WindowPage.lua's and the search box WindowSearch.lua's; they share this
-- table. Everything here is plain frames, so the window opens, moves and
-- shuts in a fight like any other.

local _, ns = ...
local L = ns.L

local UI = {}
ns.WindowUI = UI

-- At UI scale 1 a 1280x720 screen is 1365 x 768 units, which leaves room
-- above and below; inside, the header, footer and sidebar are fixed and the
-- content scrolls. The window can be made bigger by the grip in its corner
-- (more of a page at once): UI.WIDTH and UI.HEIGHT are then its size as it
-- stands, never less than the usual one (UI.MIN_W, UI.MIN_H).
UI.WIDTH, UI.HEIGHT = 820, 600
UI.MIN_W, UI.MIN_H = UI.WIDTH, UI.HEIGHT
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

-- A round dot with a soft glow, as the mock-up draws the sidebar's red dot and
-- a fold's gold one: the client's round portrait mask, tinted, over two
-- larger and fainter copies of itself, the glow falling away in steps. A
-- frame, so they show, hide and move as one.
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DOT_LAYERS = { { 15, 0.15 }, { 11, 0.35 }, { 7, 1 } }

function UI.Dot(parent, colour)
	local dot = CreateFrame("Frame", nil, parent)
	dot:SetSize(7, 7)
	for i, layer in ipairs(DOT_LAYERS) do
		local t = dot:CreateTexture(nil, "OVERLAY", nil, i)
		t:SetTexture(ROUND)
		t:SetSize(layer[1], layer[1])
		t:SetPoint("CENTER", dot, "CENTER", 0, 0)
		t:SetVertexColor(colour[1], colour[2], colour[3], layer[2])
	end
	return dot
end

-- SetGradient changed shape between client generations; tried as
-- Prompt/Prompt.lua tries it, over a white texture for the colours to tint,
-- with a flat colour that always works behind it. Vertical runs bottom to top.
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
-- own (the build line, a combat line's trailing break). Byte ranges spelt
-- out: %x and %s follow the C library's locale, and under a Western one %s
-- takes 0xA0, the last byte of "à" and of the Chinese "加".
local HEX8 = "|c" .. ("[0-9A-Fa-f]"):rep(8)

function UI.Plain(text)
	text = tostring(text or "")
	text = text:gsub(HEX8, ""):gsub("|r", "")
	return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
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

-- A control's hidden or disabled rule as the window paints it. One that
-- throws is named once in /manners errors and read as true -- the control
-- left out, or greyed out -- as a row whose Refresh throws is left out: one
-- bad rule never sends the player to the old dialog, which asks the same
-- rules anyway.
local thrown = {}

local function Rule(rule, item)
	local ok, on = pcall(rule, item)
	if ok then return on end
	if not thrown[item.path] then
		thrown[item.path] = true
		ns.Guard("options row " .. tostring(item.path), error, on, 0)
	end
	return true
end

function UI.Hidden(item) return Rule(ns.WindowBind.Hidden, item) end
function UI.OwnHidden(item) return Rule(ns.WindowBind.OwnHidden, item) end
function UI.Disabled(item) return Rule(ns.WindowBind.Disabled, item) end

---------------------------------------------------------------------------
-- the peek: the window fades so the real prompt behind it shows
---------------------------------------------------------------------------

local PEEK_ALPHA, FADE_OUT, FADE_IN, PEEK_AFTER, HOVER_DELAY = 0.25, 0.15, 0.2, 1.5, 0.4
local peek = { held = false, hover = false, untilAt = 0, alpha = 1, hoverToken = 0 }
UI.peek = peek

-- No peek in a fight: Look's changes wait for it to end anyway. A hold and the
-- 1.5 s after a change count only while Look is the page (the colour picker can
-- be left up behind another, and the player can leave inside the 1.5 s), and
-- the pointer on the preview button only while a preview runs (it can end
-- without the pointer moving).
--
-- A hold also lasts only while its cause does: the colour picker up, or a
-- mouse button down. Its release can go missing -- a slider laid out afresh
-- under the pointer misses its OnMouseUp -- and in 1.6.0 the window then stayed
-- faded until the next click.
local function HoldStands()
	local picker = _G.ColorPickerFrame
	if type(picker) == "table" and picker.IsShown and picker:IsShown() then return true end
	local down = _G.IsMouseButtonDown
	if type(down) ~= "function" then return true end
	return down("LeftButton") and true or false
end

function UI.PeekTarget()
	if InCombatLockdown() then return 1 end
	if peek.held and not HoldStands() then peek.held = false end
	-- A change, a drag or the colour picker fades the window only with *Fade
	-- this window while I change the look* on (prompt.peekOnChange, off by
	-- default); the pointer resting on the preview button always does.
	local prompt = ns.db and ns.db.profile and ns.db.profile.prompt
	local onLook = UI.page == "appearance" and prompt ~= nil and prompt.peekOnChange == true
	local held = (peek.held or ns.WindowWidgets.PickerUp()) and onLook
	local hover = peek.hover and ns.Prompt ~= nil and ns.Prompt:InTest()
	if held or hover or (onLook and GetTime() < peek.untilAt) then return PEEK_ALPHA end
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

-- After any committed change: the peek for a change on Look while Look is
-- the page (a box on it commits as the player leaves for another, and the
-- window must not fade over that one), and a repaint of everything the
-- change can reach.
function UI.Changed(item)
	if OnLook(item) and UI.page == "appearance" and not InCombatLockdown() then
		peek.untilAt = GetTime() + PEEK_AFTER
	end
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

-- What the widgets are handed with every item. Relayout is asked for by a
-- row that changed height by itself (an error under a box, a name added to
-- the never-offer list): the page is laid out again, values left as they are.
UI.ctx = {
	OnChange = function(item) ns.Guard("options window", UI.Changed, item) end,
	OnHold = function(on) ns.Guard("options window", UI.Held, on) end,
	Repaint = function() ns.Guard("options repaint", UI.Refresh) end,
	Relayout = function() ns.Guard("options relayout", UI.Relayout) end,
	ScrollPage = function(delta) ns.Guard("options window", UI.ScrollBy, -(tonumber(delta) or 0) * 48) end,
}

---------------------------------------------------------------------------
-- the preview: the real prompt, started for the player twice
---------------------------------------------------------------------------

local function StartPreview()
	if InCombatLockdown() or not ns.Prompt or ns.Prompt:InTest() then return end
	if not ns.OptionsPage.HasPrompt() then return end
	-- Not over an unlocked prompt: the mock-up would stand where "Drag to move"
	-- is, and Move the prompt put that there. Show me the prompt still asks.
	if not ns.db.profile.prompt.locked then return end
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
end

local function BuildBody(f)
	local side = { buttons = {} }
	UI.side = side
	side.frame = CreateFrame("Frame", nil, f)
	local bg = UI.Solid(side.frame, "BACKGROUND", C.side)
	bg:SetAllPoints()
	UI.Dress.Pane(side.frame, side.frame, UI.SIDEBAR, UI.HEIGHT - UI.HEADER - UI.FOOTER)
	local edge = UI.Solid(side.frame, "BORDER", C.line)
	edge:SetPoint("TOPRIGHT")
	edge:SetPoint("BOTTOMRIGHT")
	edge:SetWidth(1)

	local view = {}
	UI.view = view
	view.scroll = CreateFrame("ScrollFrame", nil, f)
	local back = UI.Solid(view.scroll, "BACKGROUND", C.content)
	back:SetAllPoints()
	UI.Dress.Pane(view.scroll, view.scroll, UI.WIDTH - UI.SIDEBAR - 13, UI.HEIGHT - UI.HEADER - UI.FOOTER)
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

-- The anchors SetPoint takes. Any other name throws, and a window that cannot
-- be placed is a window that never opens.
local ANCHORS = {
	CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- An offset some screen has, as the ledger window judges its own.
local function Offset(v)
	return type(v) == "number" and v == v and math.abs(v) < 10000
end

-- Where it was left, unless the saved file says something SetPoint cannot
-- take (a hand edit, a damaged file): then the centre, and the saved place is
-- forgotten, so it is not met again at every login.
local function Place(f)
	local s = UI.State()
	f:ClearAllPoints()
	local relPoint = s.relPoint
	if relPoint == nil then relPoint = s.point end
	if ANCHORS[s.point] and ANCHORS[relPoint] and Offset(s.x) and Offset(s.y) then
		f:SetPoint(s.point, UIParent, relPoint, s.x, s.y)
	else
		s.point, s.relPoint, s.x, s.y = nil, nil, nil, nil
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

---------------------------------------------------------------------------
-- the size: a grip in the corner, kept in the window's own state
---------------------------------------------------------------------------

-- The biggest the screen leaves room for, and never less than the usual size.
local function MaxSize()
	local w = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
	local h = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
	w, h = tonumber(w) or 0, tonumber(h) or 0
	return math.max(UI.MIN_W, math.floor(w - 40)), math.max(UI.MIN_H, math.floor(h - 40))
end

-- A size held between the usual one and the screen's.
local function Clamp(v, low, high)
	if type(v) ~= "number" or v ~= v then return low end
	return math.max(low, math.min(high, math.floor(v + 0.5)))
end

-- The size it was left at; a saved size no screen has is forgotten.
function UI.SavedSize()
	local s = UI.State()
	local maxW, maxH = MaxSize()
	if (s.w ~= nil and not Offset(s.w)) or (s.h ~= nil and not Offset(s.h)) then s.w, s.h = nil, nil end
	return Clamp(s.w, UI.MIN_W, maxW), Clamp(s.h, UI.MIN_H, maxH)
end

-- The window's size as it now stands: the panes tiled to it, the rows laid
-- out across its width and the page scrolled within its height. While the
-- grip is held the page is painted at most ten times a second; let go, it is
-- painted in full.
local sizedAt = 0
function UI.Resized(final)
	local f = UI.frame
	if not f or not UI.view then return end
	local w, h = tonumber(f:GetWidth()) or 0, tonumber(f:GetHeight()) or 0
	if w < 1 or h < 1 then return end
	UI.WIDTH, UI.HEIGHT = math.floor(w + 0.5), math.floor(h + 0.5)
	UI.view.child:SetWidth(UI.WIDTH - UI.SIDEBAR - 13)
	UI.Dress.Retile()
	local now = GetTime()
	if final or now - sizedAt >= 0.1 then
		sizedAt = now
		if UI.Shown() then UI.Refresh() end
	end
end

-- Puts the window at a size and keeps it: the grip let go, and its right
-- click back to the usual size.
function UI.SetWindowSize(w, h)
	local f = UI.frame
	if not f then return end
	local maxW, maxH = MaxSize()
	w, h = Clamp(w, UI.MIN_W, maxW), Clamp(h, UI.MIN_H, maxH)
	f:SetSize(w, h)
	local s = UI.State()
	if w == UI.MIN_W and h == UI.MIN_H then s.w, s.h = nil, nil else s.w, s.h = w, h end
	UI.Resized(true)
end

local function BuildGrip(f)
	if f.SetResizable then f:SetResizable(true) end
	local maxW, maxH = MaxSize()
	if f.SetResizeBounds then
		f:SetResizeBounds(UI.MIN_W, UI.MIN_H, maxW, maxH)
	else
		if f.SetMinResize then f:SetMinResize(UI.MIN_W, UI.MIN_H) end
		if f.SetMaxResize then f:SetMaxResize(maxW, maxH) end
	end
	-- Over the moulding (WindowDress.lua puts it 30 levels up), in the corner
	-- below the footer's Close.
	local grip = CreateFrame("Button", nil, f)
	UI.grip = grip
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(f:GetFrameLevel() + 40)
	-- The chat frame's own grabber: up, held (while dragging) and lit on hover.
	local GRAB = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"
	local face = grip:CreateTexture(nil, "ARTWORK")
	face:SetAllPoints()
	face:SetTexture(GRAB .. "Up")
	grip.face = face
	local lit = grip:CreateTexture(nil, "HIGHLIGHT")
	lit:SetAllPoints()
	lit:SetTexture(GRAB .. "Highlight")
	grip:RegisterForClicks("RightButtonUp")
	grip:SetScript("OnMouseDown", UI.Guarded(function(_, button)
		if button ~= "LeftButton" then return end
		UI.sizing = true
		face:SetTexture(GRAB .. "Down")
		f:StartSizing("BOTTOMRIGHT")
	end))
	grip:SetScript("OnMouseUp", UI.Guarded(function(_, button)
		face:SetTexture(GRAB .. "Up")
		if button ~= "LeftButton" or not UI.sizing then return end
		UI.sizing = false
		-- As a move is: where it now sits kept in the window's own state.
		UI.Dropped()
		UI.SetWindowSize(f:GetWidth(), f:GetHeight())
	end))
	grip:SetScript("OnClick", UI.Guarded(function() UI.SetWindowSize(UI.MIN_W, UI.MIN_H) end))
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(L["Drag to resize the window."], 1, 1, 1)
		GameTooltip:AddLine(L["Right-click: back to its usual size."], nil, nil, nil, true)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScript("OnSizeChanged", UI.Guarded(function() UI.Resized(not UI.sizing) end))
end

-- A fight starting. The client says so just before lockdown begins, so the
-- repaint Core asks for then still reads every control as live; one more on
-- the next frame, under lockdown, greys out what the game refuses and puts
-- the page's combat line in the strip. A key being waited for lets go now:
-- the next key pressed is for the fight.
local fightToken = 0

local function FightStarting()
	local W = ns.WindowWidgets
	if W and W.StopCapture then W.StopCapture() end
	if not UI.Shown() then return end
	fightToken = fightToken + 1
	local token = fightToken
	C_Timer.After(0, function()
		if token == fightToken and UI.Shown() then ns.Guard("options repaint", UI.Refresh) end
	end)
end

-- The macro Put Manners on an action bar put on the cursor was dropped or put
-- away: the line saying where to drop it goes, with nothing else repainted.
-- Asked at every change of the cursor, so it answers at once for any other.
local function CursorChanged()
	if ns.macroOnCursor and UI.Shown() and not ns.Setup.Carrying() then UI.Refresh() end
end

local function Hidden()
	ns.OptionsPage.reportOpen = false
	ns.OptionsPage.shareOpen = false
	ns.OptionsPage.selftestText = nil
	UI.session.stoppedPreview = false
	UI.EndPeek()
	if UI.CloseResults then UI.CloseResults() end
	GameTooltip:Hide()
	-- Nothing on screen for the prompt's repaint to keep up to date.
	UI.rightNowPainted = nil
end

function UI.Build()
	local f = CreateFrame("Frame", "MannersOptions", UIParent)
	UI.frame = f
	f:Hide()
	-- The size it was left at (UI.SavedSize), the usual one at first.
	UI.WIDTH, UI.HEIGHT = UI.SavedSize()
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
	-- What the window wears over all of it (WindowDress.lua).
	UI.Dress.Window(f)
	BuildGrip(f)
	f:SetScript("OnHide", UI.Guarded(Hidden))
	f:SetScript("OnUpdate", function(_, elapsed) Fade(elapsed or 0) end)
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	-- Where a client has no such event the registration is refused and the
	-- hint stays until the next repaint, which is all it costs.
	pcall(f.RegisterEvent, f, "CURSOR_CHANGED")
	f:SetScript("OnEvent", UI.Guarded(function(_, event)
		if event == "CURSOR_CHANGED" then return CursorChanged() end
		return FightStarting()
	end))
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

function UI.Open(pageId, quiet)
	if not UI.frame then UI.Build() end
	local f = UI.frame
	local was, wasShown = UI.page, f:IsShown()
	f:Show()
	f:Raise()
	-- A profile that has never been set up opens on its two questions.
	if not pageId and ns.QuickSetup and ns.QuickSetup.Asking() then pageId = "general" end
	local id = PageToOpen(pageId)
	UI.ShowPage(id)
	-- Opening the window onto Look is opening Look.
	if id == "appearance" and was == id and not wasShown then UI.LookOpened() end
	-- The very first time, out of a fight and with a prompt, the preview
	-- starts by itself once.
	local s = UI.State()
	if not quiet and not s.previewShown and not InCombatLockdown() and ns.OptionsPage.HasPrompt() then
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
	-- Whatever asked for the page, the search's drop-down is not over it.
	if UI.LeaveSearch then UI.LeaveSearch() end
	local was = UI.page
	-- The new page is the one in view before the old one's rows are put
	-- away: the client takes the focus from a box as it is hidden, the box
	-- commits what was typed in it, and the repaint that asks for must paint
	-- this page, not draw the old one's rows back over it.
	UI.page = id
	UI.State().page = id
	if was ~= id then UI.view.scrollY = 0 end
	if was and was ~= id then UI.HidePage(was) end
	UI.Refresh()
	if id == "appearance" and was ~= id and UI.Shown() then UI.LookOpened() end
end

-- The pages led by the Right now line (Page.RightNowNote).
local RIGHT_NOW_PAGES = { who = true, skip = true, when = true }

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
			-- The new page first, as ShowPage does.
			local was = UI.page
			UI.page = to
			UI.State().page = to
			UI.view.scrollY = 0
			if was then UI.HidePage(was) end
			UI.PaintSidebar()
		end
	end
	UI.PaintHeader()
	PlaceBody(UI.HEADER + UI.PaintStrip())
	UI.PaintPage()
	UI.PaintFooter()
	-- What the page's Right now line was painted from (see below).
	UI.rightNowPainted = RIGHT_NOW_PAGES[UI.page] and ns.OptionsPage.RightNow() or nil
end

function UI.Refresh()
	if not UI.built or UI.painting then return end
	UI.painting = true
	local ok, err = pcall(PaintAll)
	UI.painting = false
	if not ok then error(err, 0) end
end

-- The open page placed again without re-reading its rows. Asked for while a
-- paint runs, it is that paint's layout that places the row.
function UI.Relayout()
	if not UI.built or UI.painting or not UI.page or not UI.frame:IsShown() then return end
	UI.painting = true
	local ok, err = pcall(UI.PaintPage, true)
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

-- The Right now line of Who to buff, Who to skip and When to offer follows
-- the prompt: every scan ends in the prompt's repaint, and after it the open
-- page is painted again when its line would now read otherwise (somebody
-- else picked, the count behind them, a snooze, the lock). Nothing is asked
-- while no such page is up: the paint leaves rightNowPainted nil there, and
-- hiding the window clears it. The line reads what the scan left, never a
-- queue of its own (Page.RightNow).
do
	local prompt = ns.Prompt
	local refresh = prompt and prompt.Refresh
	if type(refresh) == "function" then
		prompt.Refresh = function(self, ...)
			refresh(self, ...)
			local painted = UI.rightNowPainted
			if painted ~= nil and RIGHT_NOW_PAGES[UI.page] and ns.OptionsPage.RightNow() ~= painted
				and UI.Shown() then
				ns.Guard("options repaint", UI.Refresh)
			end
		end
	end
end
