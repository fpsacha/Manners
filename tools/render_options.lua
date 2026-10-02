-- The options window for tools/render_options.py, and the addon loaded to draw
-- it; and a demo window built here, for proving the drawing and the checks.
--
-- A page is the addon on the mock client, opened the way /manners opens it
-- (ns.OpenOptions) and put into a state through the addon's own entry points:
-- a fight starting, the prompt unlocked, a snooze, every fold open, the reset
-- asked for, a search typed. Nothing here paints the window -- the renderer
-- draws what the frames were told -- so a picture is of the addon, not of this
-- file.
--
-- The demo is the one exception, and is only ever drawn as the demo. It builds
-- a window of every kind of frame the options window may use (Frame, Button,
-- EditBox, Slider and ScrollFrame, font objects, colour textures, gradients,
-- art, the close X) the way the window builds itself, so the renderer and its
-- checks can be proved on something whose right answer is known. "kinds" must
-- pass every check; "faults" plants one fault for each, tagged [a1], [b1] and
-- so on in its text, and the checks must find exactly those.

-- `dir` holds the mock and the recorder, `addonDir` the addon drawn. `measure`
-- and `wrap` are the renderer's own, so what the addon is told about its text
-- is what the picture shows.
local dir, addonDir, locale, class, measure, wrap = ...
addonDir = addonDir or dir
if locale == "" or locale == "enUS" then locale = nil end
if class == "" then class = nil end

dofile(dir .. "/tests/mockapi.lua")
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local R = {}
local FILES = dofile(dir .. "/tests/addonfiles.lua")(addonDir)

-- 1280 x 720 at UI scale 1, the screen IA.md 1.1 sizes the window for.
local SCREEN = { width = 1365, height = 768 }
-- Sidebar order, used when the layout cannot be asked.
R.PAGES = { "general", "who", "skip", "when", "click", "appearance", "profiles", "diagnostics" }

local function fresh()
	Mock.reset()
	Mock.screenHeight = SCREEN.height
	FT.uninstall()
	FT.install()
	FT.measure, FT.wrap, FT.screen = measure, wrap, SCREEN
end

local function load()
	fresh()
	-- After the reset, which puts the client back to an English mage, and
	-- before the files load: Locales/Init.lua reads the language once.
	Mock.locale = locale
	Mock.class = class or "MAGE"
	local ns = {}
	for _, file in ipairs(FILES) do
		local chunk, err = loadfile(addonDir .. "/" .. file)
		if not chunk then error("load " .. file .. ": " .. tostring(err)) end
		chunk("Manners", ns)
	end
	return ns
end

local function boot(ns)
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.runTimers(3)
	Mock.advance(60)
end

-- The pages in sidebar order, from the layout when this tree has one.
function R.pages()
	local ns = load()
	local out, layout = {}, ns.WindowLayout
	for _, group in ipairs(layout and layout.groups or {}) do
		for _, id in ipairs(group) do out[#out + 1] = id end
	end
	if #out == 0 then out = R.PAGES end
	return out
end

-- ------------------------------------------------------------------ finding things

local function walk(frame, visit)
	visit(frame)
	for _, child in ipairs(frame._children or {}) do walk(child, visit) end
end

local function shown(r)
	return FT.visible(r) and r._shown ~= false
end

-- The text a frame shows, from its first font string.
local function labelOf(frame)
	for _, child in ipairs(frame._children or {}) do
		if child._kind == "FontString" and child._text then return tostring(child._text) end
	end
end

-- The search box: the window's own handle on it if it keeps one, else the
-- topmost shown edit box in the sidebar (IA 1.8 puts it at the sidebar's top).
local function searchBox(win)
	if type(win.search) == "table" and win.search._kind == "EditBox" then return win.search end
	local wlo = FT.span(win, "x")
	local best, bestTop
	walk(win, function(r)
		if r._kind ~= "EditBox" or not shown(r) then return end
		local lo = FT.span(r, "x")
		local _, top = FT.span(r, "y")
		if lo and wlo and lo < wlo + 170 and (not bestTop or top > bestTop) then best, bestTop = r, top end
	end)
	return best
end

local function buttonLabelled(win, label)
	local found
	walk(win, function(r)
		if not found and r._kind == "Button" and shown(r) and labelOf(r) == label then found = r end
	end)
	return found
end

-- The client runs every shown frame's OnUpdate each frame, and the mock runs
-- none: a second of them, twenty to the second, with the clock and the timers
-- moving, so a fade the window drives itself has run its course.
local function frames(win, seconds)
	for _ = 1, math.floor(seconds * 20 + 0.5) do
		Mock.advance(0.05)
		walk(win, function(f)
			local fn = f._kind ~= "Texture" and f._kind ~= "FontString" and f.scripts and f.scripts.OnUpdate
			if fn and shown(f) then fn(f, 0.05) end
		end)
		Mock.runTimers()
	end
	FT.settle()
end

-- ------------------------------------------------------------------ states

-- States set before the window opens, and states acted out once it is open.
local BEFORE, AFTER = {}, {}

function BEFORE.unlocked(ns)
	ns.db.profile.prompt.locked = false
	if ns.Prompt and ns.Prompt.ApplyStyle then ns.Prompt:ApplyStyle() end
end

function BEFORE.snoozed(ns)
	assert(ns.StartSnooze, "this tree has no ns.StartSnooze")
	ns.StartSnooze(15)
end

function AFTER.combat(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
end

-- Every folded section open, as the window remembers them (IA 1.5): shut, the
-- keys written where the window keeps them, and opened again.
AFTER["folds-open"] = function(ns, _, page)
	local open = {}
	for _, p in pairs(ns.WindowLayout and ns.WindowLayout.pages or {}) do
		for _, section in ipairs(p.sections or {}) do
			if section.fold and section.key then open[section.key] = true end
		end
	end
	ns.CloseOptions()
	local saved = ns.db.global and ns.db.global.window
	assert(type(saved) == "table", "the window keeps no ns.db.global.window")
	saved.open = open
	ns.OpenOptions(page)
end

-- The confirm box, asked for the way a player asks: the footer's reset pressed.
-- A page without a reset gets the same box opened directly with its words.
function AFTER.modal(ns, win, _, notes)
	local B, W = ns.WindowBind, ns.WindowWidgets
	local ctx = { Window = win, OnChange = function() end, OnHold = function() end }
	local item = B and B.Item and B.Item("advanced.resetAdvanced", {}, ctx)
	local label = item and B.Text(item, "name")
	local button = label and buttonLabelled(win, label)
	if button and button.Click then
		button:Click("LeftButton")
		notes[#notes + 1] = "modal: pressed " .. label
		return
	end
	assert(W and W.Modal, "this tree has no ns.WindowWidgets.Modal")
	W.Modal(win, item and B.Text(item, "confirmText") or "?", function() end, function() end)
	notes[#notes + 1] = "modal: no reset on this page, the box opened directly"
end

function AFTER.search(ns, win, text)
	local box = searchBox(win)
	assert(box, "no search box in the window's sidebar")
	if box.SetFocus then box:SetFocus() end
	box:SetText(text or "")
	local changed = box.scripts and box.scripts.OnTextChanged
	if changed then changed(box, true) end
	-- Past the 0.15 s the search waits for typing to stop.
	Mock.runTimers(0.3)
end

-- "combat\nsearch\tthe words" from the renderer: one state a line, its
-- argument after a tab.
local function parseStates(spec)
	local out = {}
	for line in tostring(spec or ""):gmatch("[^\n]+") do
		local name, arg = line:match("^([^\t]+)\t?(.*)$")
		out[#out + 1] = { name = name, arg = arg }
	end
	return out
end

local function apply(list, states, ns, win, page, notes)
	for _, s in ipairs(states) do
		local fn = list[s.name]
		if fn then fn(ns, win, s.arg ~= "" and s.arg or page, notes) end
	end
end

-- The tree with the window open on `page` in `spec`'s states.
function R.page(page, spec)
	local states = parseStates(spec)
	for _, s in ipairs(states) do
		assert(BEFORE[s.name] or AFTER[s.name], "no such state: " .. tostring(s.name))
	end
	local ns, notes, win = load(), {}, nil
	local ok, err = pcall(function()
		boot(ns)
		apply(BEFORE, states, ns, nil, page, notes)
		assert(ns.OpenOptions, "this tree has no ns.OpenOptions")
		ns.OpenOptions(page)
		win = ns.OptionsWindow
		assert(win, "ns.OptionsWindow is not built: this tree does not have the new options window")
		for _, s in ipairs(states) do
			local fn = AFTER[s.name]
			if fn then fn(ns, win, s.name == "search" and s.arg or page, notes) end
		end
		-- Past the window's fades, every timer run and every one-shot settled.
		Mock.runTimers()
		frames(win, 1)
	end)
	return {
		tree = FT.snapshot(UIParent),
		window = win and win._serial,
		page = ns.OptionsTab and ns.OptionsTab() or nil,
		requested = page,
		failed = not ok and tostring(err) or nil,
		notes = notes,
		now = Mock.now,
		screen = SCREEN,
		errors = ns.errors and #ns.errors or 0,
		firstError = ns.errors and ns.errors[1] and (tostring(ns.errors[1].where) .. " -> "
			.. tostring(ns.errors[1].err)) or nil,
	}
end

-- ------------------------------------------------------------------ the demo

local D = {}
local FRIZ = "Fonts\\FRIZQT__.TTF"

local function hex(s, a)
	return tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255,
		tonumber(s:sub(5, 6), 16) / 255, a or 1
end

-- mockup.html's colours.
D.C = {
	win = { hex("0f0f13") }, head1 = { hex("1e1c22") }, head2 = { hex("121116") },
	side = { hex("141418") }, content = { hex("0d0d11") }, edge = { hex("4d412c") },
	line = { 1, 1, 1, 0.09 }, field = { hex("060608") }, fieldEdge = { hex("3d3c45") },
	gold = { 1, 0.82, 0, 1 }, rule = { 1, 0.82, 0, 0.42 }, hint = { hex("8e8b84") },
	red = { hex("ff8080") }, dot = { hex("ff4a3a") }, strip = { 1, 0.82, 0, 0.055 },
}

-- The client's font objects; the mock's when it has them.
function D.font(name)
	if type(_G[name]) == "table" then return _G[name] end
	local spec = FT.FONTS[name]
	return { _name = name, GetFont = function() return spec[1], spec[2], "" end }
end

function D.tex(parent, layer, c, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return t
end

function D.fill(parent, layer, c, sub)
	local t = D.tex(parent, layer, c, sub)
	t:SetAllPoints(parent)
	return t
end

-- Borders are four textures, as Interface 4 asks.
function D.border(frame, c)
	local top, bottom = D.tex(frame, "BORDER", c), D.tex(frame, "BORDER", c)
	top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(1)
	local left, right = D.tex(frame, "BORDER", c), D.tex(frame, "BORDER", c)
	left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(1)
	right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(1)
end

function D.text(parent, font, s, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(D.font(font))
	fs:SetJustifyH(justify or "LEFT")
	fs:SetText(s)
	return fs
end

-- A button sized to its label, a field-coloured box with a gold edge.
function D.button(parent, label, height)
	local b = CreateFrame("Button", nil, parent)
	D.fill(b, "BACKGROUND", D.C.field)
	D.border(b, D.C.edge)
	b.label = D.text(b, "GameFontNormal", label, "CENTER")
	b.label:SetPoint("CENTER")
	b:SetSize(math.ceil(b.label:GetStringWidth()) + 24, height or 22)
	return b
end

-- A toggle: a Button holding its box, its tick and its label.
function D.toggle(parent, label, on, disabled)
	local b = CreateFrame("Button", nil, parent)
	local box = D.tex(b, "ARTWORK", D.C.field)
	box:SetSize(14, 14)
	box:SetPoint("LEFT", 2, 0)
	local tick = b:CreateTexture(nil, "OVERLAY")
	tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	tick:SetSize(18, 18)
	tick:SetPoint("CENTER", box, "CENTER")
	tick:SetShown(on)
	if disabled then tick:SetDesaturated(true) b:Disable() end
	b.label = D.text(b, disabled and "GameFontDisable" or "GameFontHighlight", label)
	b.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
	b:SetSize(math.ceil(b.label:GetStringWidth()) + 28, 20)
	return b
end

-- Laying rows down the scroll child, top to bottom.
local Rows = {}
Rows.__index = Rows

function D.rows(child, width)
	return setmetatable({ child = child, width = width, y = 14 }, Rows)
end

function Rows:put(frame, height, indent, gap)
	indent = indent or 0
	frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", 16 + indent, -self.y)
	self.y = self.y + height + (gap or 6)
	return frame
end

function Rows:row(height, indent)
	local f = CreateFrame("Frame", nil, self.child)
	f:SetSize(self.width - 32 - (indent or 0), height)
	return self:put(f, height, indent)
end

-- A wrapped note as tall as its lines: measured, as the window measures it.
function Rows:note(s, font, color, indent)
	local f = CreateFrame("Frame", nil, self.child)
	local fs = D.text(f, font or "GameFontHighlightSmall", s)
	if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
	local width = self.width - 32 - (indent or 0)
	fs:SetWidth(width)
	fs:SetPoint("TOPLEFT")
	local height = math.ceil(fs:GetStringHeight())
	f:SetSize(width, height)
	f.text = fs
	return self:put(f, height, indent)
end

-- A section title: Friz 13 in gold over a thin gold rule (IA 1.5).
function Rows:section(title)
	self.y = self.y + 8
	local f = self:row(22)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FRIZ, 13, "")
	fs:SetTextColor(1, 0.82, 0, 1)
	fs:SetText(title)
	fs:SetPoint("TOPLEFT")
	local rule = D.tex(f, "ARTWORK", D.C.rule)
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	return f
end

function Rows:toggle(label, on, indent, disabled)
	local b = D.toggle(self.child, label, on, disabled)
	return self:put(b, 20, indent)
end

-- A label with a control to its right, the pair the window lays on one row.
-- `make(parent)` builds the control in the row.
function Rows:labelled(label, make, indent)
	local f = self:row(24, indent)
	local fs = D.text(f, "GameFontHighlight", label)
	fs:SetPoint("LEFT")
	make(f):SetPoint("LEFT", f, "LEFT", 220, 0)
	return f
end

-- ------------------------------------------------------------------ demo controls

function D.select(parent, value)
	local b = CreateFrame("Button", nil, parent)
	D.fill(b, "BACKGROUND", D.C.field)
	D.border(b, D.C.fieldEdge)
	b:SetSize(220, 22)
	local fs = D.text(b, "GameFontHighlightSmall", value)
	fs:SetPoint("LEFT", 8, 0)
	fs:SetPoint("RIGHT", -22, 0)
	fs:SetWordWrap(false)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	arrow:SetSize(12, 12)
	arrow:SetPoint("RIGHT", -6, 0)
	return b
end

function D.edit(parent, width, height, s, multi)
	local e = CreateFrame("EditBox", nil, parent)
	D.fill(e, "BACKGROUND", D.C.field)
	D.border(e, D.C.fieldEdge)
	e:SetFontObject(D.font("GameFontHighlightSmall"))
	e:SetTextInsets(6, 6, 4, 4)
	e:SetAutoFocus(false)
	e:SetMultiLine(multi and true or false)
	e:SetSize(width, height)
	e:SetText(s)
	e:SetCursorPosition(0)
	return e
end

function D.slider(parent, min, max, value)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(300, 20)
	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(220, 16)
	s:SetPoint("LEFT")
	local track = D.tex(s, "BACKGROUND", D.C.fieldEdge)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local thumb = D.tex(s, "OVERLAY", D.C.gold)
	thumb:SetSize(8, 16)
	s:SetThumbTexture(thumb)
	s:SetMinMaxValues(min, max)
	s:SetValueStep(0.05)
	s:SetValue(value)
	local box = D.edit(holder, 52, 20, string.format("%.2f", value))
	box:SetJustifyH("RIGHT")
	box:SetPoint("LEFT", s, "RIGHT", 10, 0)
	return holder
end

-- A number box with nudge arrows (advanced.x / advanced.y).
function D.number(parent, value)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(120, 22)
	local box = D.edit(holder, 64, 22, tostring(value))
	box:SetPoint("LEFT")
	for i, dir in ipairs({ "Up", "Down" }) do
		local nudge = CreateFrame("Button", nil, holder)
		nudge:SetSize(16, 11)
		nudge:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, -(i - 1) * 11)
		local art = nudge:CreateTexture(nil, "ARTWORK")
		art:SetTexture("Interface\\Buttons\\Arrow-" .. dir .. "-Up")
		art:SetAllPoints()
	end
	return holder
end

function D.swatch(parent, r, g, b)
	local s = CreateFrame("Button", nil, parent)
	s:SetSize(36, 18)
	D.fill(s, "ARTWORK", { r, g, b, 1 })
	D.border(s, D.C.fieldEdge)
	return s
end

-- The never-offer list in a box that cuts what it holds (SetClipsChildren):
-- the band behind the names runs well past it and is cut at its edges.
function D.clipped(rows)
	local box = rows:row(46)
	box:SetClipsChildren(true)
	D.fill(box, "BACKGROUND", D.C.field)
	local band = D.tex(box, "ARTWORK", { 1, 1, 1, 1 })
	band:SetGradient("HORIZONTAL", CreateColor(0.30, 0.22, 0.05, 1), CreateColor(0.05, 0.05, 0.08, 1))
	band:SetPoint("TOPLEFT", box, "TOPLEFT", -40, 3)
	band:SetSize(900, 7)
	for i, name in ipairs({ "Brannoc Vale", "Corwin Ash", "Delphine Moor" }) do
		local fs = D.text(box, "GameFontHighlightSmall", name)
		fs:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 13)
	end
	return box
end

-- A report box: a multi-line edit box in its own scroll frame, scrolled to
-- its end, the first lines off its top.
function D.report(rows, s)
	local holder = rows:row(44)
	D.border(holder, D.C.fieldEdge)
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", -1, 1)
	local width = rows.width - 34
	local box = D.edit(scroll, width, 10, s, true)
	local probe = holder:CreateFontString(nil, "ARTWORK")
	probe:SetFontObject(D.font("GameFontHighlightSmall"))
	probe:SetWidth(width - 12)
	probe:SetText(s)
	probe:Hide()
	box:SetHeight(math.ceil(probe:GetStringHeight()) + 8)
	scroll:SetScrollChild(box)
	scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
	return holder
end

-- ------------------------------------------------------------------ demo chrome

function D.header(win, strip)
	local head = CreateFrame("Frame", nil, win)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(44)
	local band = D.fill(head, "BACKGROUND", { 1, 1, 1, 1 })
	band:SetGradient("VERTICAL", CreateColor(D.C.head2[1], D.C.head2[2], D.C.head2[3], 1),
		CreateColor(D.C.head1[1], D.C.head1[2], D.C.head1[3], 1))
	local icon = head:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetSize(24, 24)
	icon:SetPoint("LEFT", 12, 0)
	local title = D.text(head, "GameFontNormalLarge", "Manners")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
	close:SetPoint("RIGHT", -8, 0)
	local on = D.toggle(head, "Manners is on", true)
	on:SetPoint("RIGHT", close, "LEFT", -14, 0)
	local snooze = D.button(head, "Snooze")
	snooze:SetPoint("RIGHT", on, "LEFT", -12, 0)
	local preview = D.button(head, "Show me the prompt")
	preview:SetPoint("RIGHT", snooze, "LEFT", -8, 0)
	if not strip then return 44 end
	local line = CreateFrame("Frame", nil, win)
	line:SetPoint("TOPLEFT", 0, -44)
	line:SetPoint("TOPRIGHT", 0, -44)
	line:SetHeight(26)
	D.fill(line, "BACKGROUND", D.C.strip)
	local words = D.text(line, "GameFontHighlightSmall",
		"Unlocked -- the prompt is up to be dragged and casts nothing until you lock it.")
	words:SetPoint("LEFT", 12, 0)
	local lock = D.button(line, "Lock it", 20)
	lock:SetPoint("RIGHT", -10, 0)
	return 70
end

local SIDEBAR = {
	{ "Start here", "Interface\\Icons\\INV_Misc_Book_09" }, false,
	{ "Who to buff", "Interface\\Icons\\Spell_Holy_MagicalSentry", selected = true },
	{ "Who to skip", "Interface\\Icons\\Ability_Rogue_Disguise" },
	{ "When to offer", "Interface\\Icons\\INV_Misc_PocketWatch_01", warn = true },
	{ "What I say", "Interface\\Icons\\INV_Letter_15" },
	{ "Look", "Interface\\Icons\\INV_Misc_Spyglass_03" }, false,
	{ "Profiles", "Interface\\Icons\\INV_Misc_Note_05", second = "Default" },
	{ "Diagnostics", "Interface\\Icons\\INV_Misc_Gear_01" },
}

function D.entry(side, spec, y)
	local b = CreateFrame("Button", nil, side)
	local h = spec.second and 34 or 24
	b:SetPoint("TOPLEFT", 6, -y)
	b:SetPoint("TOPRIGHT", -6, -y)
	b:SetHeight(h)
	if spec.selected then
		D.fill(b, "BACKGROUND", { 1, 0.82, 0, 0.08 })
		local bar = D.tex(b, "ARTWORK", D.C.gold)
		bar:SetPoint("TOPLEFT") bar:SetPoint("BOTTOMLEFT") bar:SetWidth(3)
	end
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(spec[2])
	icon:SetSize(16, 16)
	icon:SetPoint("TOPLEFT", 8, -4)
	local name = D.text(b, "GameFontHighlight", spec[1])
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -2)
	if spec.second then
		local sub = D.text(b, "GameFontDisableSmall", spec.second)
		sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	end
	if spec.warn then
		local dot = D.tex(b, "OVERLAY", D.C.dot)
		dot:SetSize(6, 6)
		dot:SetPoint("RIGHT", -8, 0)
	end
	return y + h + 2
end

function D.sidebar(win, top)
	local side = CreateFrame("Frame", nil, win)
	side:SetPoint("TOPLEFT", 0, -top)
	side:SetPoint("BOTTOMLEFT", 0, 34)
	side:SetWidth(160)
	D.fill(side, "BACKGROUND", D.C.side)
	local search = D.edit(side, 144, 22, "")
	search:SetPoint("TOPLEFT", 8, -10)
	local hint = D.text(search, "GameFontDisableSmall", "Search")
	hint:SetPoint("LEFT", 8, 0)
	win.search = search
	local y = 44
	for _, spec in ipairs(SIDEBAR) do
		if spec then
			y = D.entry(side, spec, y)
		else
			local hair = D.tex(side, "ARTWORK", D.C.line)
			hair:SetHeight(1)
			hair:SetPoint("TOPLEFT", 10, -y - 3)
			hair:SetPoint("TOPRIGHT", -10, -y - 3)
			y = y + 8
		end
	end
end

function D.footer(win)
	local foot = CreateFrame("Frame", nil, win)
	foot:SetPoint("BOTTOMLEFT")
	foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(34)
	D.fill(foot, "BACKGROUND", D.C.head2)
	local hair = D.tex(foot, "ARTWORK", D.C.line)
	hair:SetHeight(1)
	hair:SetPoint("TOPLEFT")
	hair:SetPoint("TOPRIGHT")
	local reset = D.button(foot, "Put these back to default")
	reset:SetPoint("LEFT", 10, 0)
	local build = D.text(foot, "GameFontDisableSmall", "Manners 1.5.4", "CENTER")
	build:SetPoint("CENTER")
	local close = D.button(foot, "Close")
	close:SetPoint("RIGHT", -10, 0)
end

-- The window and its content scroll frame, as Interface 4 describes it.
function D.window(strip)
	local win = CreateFrame("Frame", "MannersOptionsDemo", UIParent)
	win:SetSize(820, 600)
	win:SetPoint("CENTER")
	win:SetFrameStrata("HIGH")
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	D.fill(win, "BACKGROUND", D.C.win)
	D.border(win, D.C.edge)
	local top = D.header(win, strip)
	D.sidebar(win, top)
	D.footer(win)
	local scroll = CreateFrame("ScrollFrame", nil, win)
	scroll:SetPoint("TOPLEFT", 161, -top)
	scroll:SetPoint("BOTTOMRIGHT", -1, 34)
	D.fill(scroll, "BACKGROUND", D.C.content)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetWidth(640)
	scroll:SetScrollChild(child)
	scroll:SetVerticalScroll(0)
	win:Raise()
	return win, D.rows(child, 640), scroll
end

-- ------------------------------------------------------------------ demo pages

local LONG = "The defaults suit most players; change these only if something bothers you. "
	.. "This sentence goes on long enough to wrap onto a second line at the content's width, "
	.. "which is the case every note on the window has to survive in German."

local REPORT = "Manners 1.5.4 on WoW Forever (Camelot), Mage, level 60, enUS.\n"
	.. "Prompt: glass, 220 x 44 at BOTTOM +300, locked. Key: SHIFT-F.\n"
	.. "Buffs: Arcane Intellect (known), Arcane Brilliance (known), Mage Armor (known).\n"
	.. "Sources: owed, group, asked, self, strangers within 10 yards.\n"
	.. "Errors this session: none."

-- `scrolled`: the content scrolled to its end, as far as the scroll frame
-- says it goes.
function D.kinds(scrolled)
	local win, rows, scroll = D.window(true)
	local title = D.text(rows.child, "GameFontNormalLarge", "Who to buff")
	rows:put(title, 18)
	rows:note("Manners offers your buff to the people you pick here, and asks first.", "GameFontHighlight")
	rows:section("What to cast")
	rows:toggle("Skip players it does nothing for", true)
	rows:note("You offer Arcane Intellect (mana users only).")
	rows:section("Offer my buff to")
	rows:toggle("People who buff me", true)
	rows:toggle("Passers-by (players near me, not in my group)", true)
	rows:labelled("Passers-by within", function(f) return D.select(f, "Nearby (about 10 yards)") end, 16)
	rows:toggle("Only in cities and inns", false, 16, true)
	-- A row hidden where the first row is: neither drawn nor checked.
	local hidden = D.toggle(rows.child, "A hidden row", true)
	hidden:SetPoint("TOPLEFT", rows.child, "TOPLEFT", 16, -14)
	hidden:Hide()
	rows:section("Size and colour")
	rows:labelled("Scale", function(f) return D.slider(f, 0.5, 2, 1.2) end)
	rows:labelled("Across (x)", function(f) return D.number(f, -120) end)
	rows:labelled("Panel colour", function(f) return D.swatch(f, 0.12, 0.10, 0.22) end)
	rows:labelled("Key", function(f) return D.button(f, "SHIFT-F") end)
	rows:section("Raid groups")
	local grid = rows:row(46)
	for i = 1, 8 do
		local t = D.toggle(grid, "Group " .. i, i ~= 3 and i ~= 7)
		t:SetPoint("TOPLEFT", ((i - 1) % 4) * 140, -math.floor((i - 1) / 4) * 24)
	end
	rows:section("Never offer to")
	rows:labelled("Add a name", function(f) return D.edit(f, 200, 22, "Brannoc Vale") end)
	rows:note("|cffff8080That name is already on the list.|r")
	D.clipped(rows)
	rows:section("Diagnostics")
	D.report(rows, REPORT)
	-- A frame faded to half, and the rules in it fade with it.
	local faded = rows:row(10)
	faded:SetAlpha(0.5)
	for i = 0, 2 do
		local rule = D.tex(faded, "ARTWORK", D.C.gold)
		rule:SetSize(120, 2)
		rule:SetPoint("LEFT", i * 140, 0)
	end
	rows:note(LONG, "GameFontHighlightSmall", D.C.hint)
	local fold = rows:row(22)
	local chevron = fold:CreateTexture(nil, "ARTWORK")
	chevron:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	chevron:SetSize(12, 12)
	chevron:SetPoint("LEFT")
	local name = D.text(fold, "GameFontNormal", "Who comes first")
	name:SetPoint("LEFT", chevron, "RIGHT", 6, 0)
	local dot = D.tex(fold, "OVERLAY", D.C.gold)
	dot:SetSize(6, 6)
	dot:SetPoint("LEFT", name, "RIGHT", 8, 0)
	rows:toggle("A row past the bottom, scrolled to", true)
	rows.child:SetHeight(rows.y + 16)
	if scrolled then scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end
	return win, {}
end

-- Each fault tagged in its own text, so a finding can be matched to it.
function D.faults()
	local win, rows = D.window(false)
	local planted = {}
	local function plant(kind, tag) planted[#planted + 1] = { kind = kind, tag = tag } end
	rows:section("Planted faults")
	local a1 = rows:row(16)
	local fs = D.text(a1, "GameFontHighlight", "[a1] A label cut short: word wrap is off and it is far too long")
	fs:SetWordWrap(false)
	fs:SetPoint("LEFT")
	fs:SetWidth(150)
	plant("a", "a1")
	local a2 = rows:row(28)
	fs = D.text(a2, "GameFontHighlightSmall",
		"[a2] Two lines at most, but this sentence needs rather more than two lines to say all it has "
		.. "to say, and it goes on saying it")
	fs:SetPoint("TOPLEFT")
	fs:SetWidth(180)
	fs:SetMaxLines(2)
	plant("a", "a2")
	local a3 = rows:row(16)
	fs = D.text(a3, "GameFontHighlightSmall", "[a3] One line high, holding three lines of wrapped text")
	fs:SetPoint("TOPLEFT")
	fs:SetSize(120, 12)
	plant("a", "a3")
	rows:toggle("[b1] Row one", true)
	rows.y = rows.y - 18
	rows:toggle("[b1] Row two, laid over row one", true)
	plant("b", "b1")
	local off = D.button(win, "[c1] Off the window")
	off:SetPoint("TOPLEFT", win, "TOPRIGHT", 20, -200)
	plant("c", "c1")
	rows:labelled("Too wide", function(f) return D.edit(f, 560, 22, "[c2] cut by the content's edge") end)
	plant("c", "c2")
	rows:note("[d1] Grey on dark, too faint to read", "GameFontHighlight", { 0.3, 0.3, 0.32, 1 })
	plant("d", "d1")
	local pale = rows:row(22)
	D.fill(pale, "BACKGROUND", { 0.86, 0.84, 0.76, 1 })
	fs = D.text(pale, "GameFontNormal", "[d2] Gold on a pale row")
	fs:SetPoint("LEFT", 6, 0)
	plant("d", "d2")
	rows.child:SetHeight(rows.y + 16)
	local below = D.button(rows.child, "[c3] Past the end of the scroll child")
	below:SetPoint("TOPLEFT", rows.child, "TOPLEFT", 16, -(rows.y + 60))
	plant("c", "c3")
	return win, planted
end

function R.demo(which)
	fresh()
	local builds = { kinds = D.kinds, faults = D.faults, scrolled = function() return D.kinds(true) end }
	local build = assert(builds[which], "no such demo: " .. tostring(which))
	local win, planted = build()
	Mock.advance(1)
	FT.settle()
	return {
		tree = FT.snapshot(UIParent),
		window = win._serial,
		page = "demo-" .. which,
		requested = "demo-" .. which,
		planted = planted,
		notes = {},
		now = Mock.now,
		screen = SCREEN,
		errors = 0,
	}
end

return R
