-- What the options window (Options/Window/Window*.lua, Options/Register.lua)
-- needs from the client beyond tests/mockapi.lua: the frame methods of
-- Interface 4 in BUILD.md, font objects, a few client globals, AceDB's
-- global section, and a stand-in for the game's Settings window.
--
-- Loaded at the end of mockapi.lua, after tests/mockwidgets.lua. Every method
-- here is added only where a frame lacks it, so the widgets' mock wins where
-- both define one, and only to frames in the window's own tree (a frame named
-- MannersOptions..., and everything made under it): the prompt and the ledger
-- go on meeting exactly the mock every scenario before this was written
-- against. Text is measured as frametree.lua's fallback measures it, half
-- the font size a character.

local function plainText(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The font size a string draws in: SetFont's, else its font object's.
local function fontSize(self)
	if self._font and self._font.size then return self._font.size end
	local object = self._fontObject
	if type(object) == "table" and object.GetFont then
		local _, size = object:GetFont()
		if type(size) == "number" then return size end
	end
	return 12
end

local function textWidth(self)
	return #plainText(self._text) * fontSize(self) * 0.5
end

local function lineCount(self)
	local width = self._width
	local w = textWidth(self)
	if self._wordWrap == false or not width or width <= 0 or w <= width then return 1 end
	return math.ceil(w / width)
end

local function self_(self) return self end

local METHODS = {
	-- Frame
	SetToplevel = self_, Raise = self_, Lower = self_, SetClipsChildren = self_, EnableKeyboard = self_,
	SetPropagateKeyboardInput = self_, SetHitRectInsets = self_, SetMotionScriptsWhileDisabled = self_,
	IsMouseOver = function() return false end,
	GetLeft = function() return 0 end, GetTop = function() return 0 end,
	GetRight = function(self) return self._width or 0 end, GetBottom = function() return 0 end,
	GetWidth = function(self) return self._width or 0 end,
	-- Regions
	SetDrawLayer = function(self, layer, sub) self._layer, self._sublevel = layer, sub return self end,
	SetSnapToPixelGrid = self_, SetTexelSnappingBias = self_,
	SetFontObject = function(self, object) self._fontObject = object return self end,
	GetFontObject = function(self) return self._fontObject end,
	SetJustifyV = self_, SetMaxLines = self_, SetNonSpaceWrap = self_, SetSpacing = self_,
	SetIndentedWordWrap = self_,
	SetWordWrap = function(self, on) self._wordWrap = on and true or false return self end,
	GetStringWidth = function(self) return math.min(textWidth(self), self._width or math.huge) end,
	GetUnboundedStringWidth = textWidth,
	GetStringHeight = function(self) return lineCount(self) * (fontSize(self) + 2) end,
	GetNumLines = lineCount,
	-- Button
	Enable = function(self) self._enabled = true return self end,
	Disable = function(self) self._enabled = false return self end,
	SetEnabled = function(self, on) self._enabled = on and true or false return self end,
	IsEnabled = function(self) return self._enabled ~= false end,
	Click = function(self, button)
		local fn = self.scripts.OnClick
		if fn and self._enabled ~= false then fn(self, button or "LeftButton", false) end
	end,
	-- Slider
	SetOrientation = self_, SetValueStep = self_, SetObeyStepOnDrag = self_,
	SetMinMaxValues = function(self, lo, hi) self._min, self._max = lo, hi return self end,
	GetMinMaxValues = function(self) return self._min or 0, self._max or 0 end,
	SetValue = function(self, value)
		local was = self._value
		self._value = value
		local fn = self.scripts.OnValueChanged
		if fn and was ~= value then fn(self, value, false) end
		return self
	end,
	GetValue = function(self) return self._value or 0 end,
	SetThumbTexture = function(self, t) self._thumb = t return self end,
	GetThumbTexture = function(self) return self._thumb end,
	-- ScrollFrame
	SetScrollChild = function(self, child) self._scrollChild = child return self end,
	GetScrollChild = function(self) return self._scrollChild end,
	SetVerticalScroll = function(self, y) self._vscroll = y return self end,
	GetVerticalScroll = function(self) return self._vscroll or 0 end,
	GetVerticalScrollRange = function(self) return self._vrange or 0 end,
	UpdateScrollChildRect = self_,
	-- EditBox
	SetAutoFocus = self_, SetMultiLine = self_, SetMaxLetters = self_, SetTextInsets = self_,
	HighlightText = self_, SetCursorPosition = self_, SetCountInvisibleLetters = self_,
	SetFocus = function(self)
		self._focus = true
		local fn = self.scripts.OnEditFocusGained
		if fn then fn(self) end
		return self
	end,
	ClearFocus = function(self)
		local had = self._focus
		self._focus = false
		local fn = self.scripts.OnEditFocusLost
		if fn and had then fn(self) end
		return self
	end,
	HasFocus = function(self) return self._focus == true end,
	GetNumLetters = function(self) return #tostring(self._text or "") end,
	Insert = function(self, text) self._text = tostring(self._text or "") .. tostring(text) return self end,
}

local decorate

-- Fills the gaps in one frame, and makes whatever it creates the same.
decorate = function(f, kind)
	if type(f) ~= "table" or f._windowMock then return f end
	f._windowMock = true
	f._kind = f._kind or kind
	for name, fn in pairs(METHODS) do
		if f[name] == nil then f[name] = fn end
	end
	-- Written down on the way through, whoever answers them, so a scenario
	-- can read the window's strata, movability and toplevel.
	for name, key in pairs({ SetFrameStrata = "_strata", SetMovable = "_movable", SetToplevel = "_toplevel" }) do
		local inner = f[name]
		f[name] = function(self, value, ...)
			self[key] = value
			if inner then return inner(self, value, ...) end
			return self
		end
	end
	local texture, fontString = f.CreateTexture, f.CreateFontString
	f.CreateTexture = function(self, ...) return decorate(texture(self, ...), "Texture") end
	f.CreateFontString = function(self, ...) return decorate(fontString(self, ...), "FontString") end
	return f
end

local function inWindow(name, parent)
	if type(name) == "string" and name:find("^MannersOptions") then return true end
	return type(parent) == "table" and parent._windowMock == true
end

local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, template, ...)
	local f = createFrame(kind, name, parent, template, ...)
	if inWindow(name, parent) then
		decorate(f, kind or "Frame")
		f._name, f._template, f._parentFrame = name, template, parent
	end
	return f
end

-- Font objects as the client has them, for a string told SetFontObject.
local FONTS = {
	GameFontNormal = 12, GameFontNormalLarge = 16, GameFontNormalSmall = 10, GameFontHighlight = 12,
	GameFontHighlightSmall = 10, GameFontDisable = 12, GameFontDisableSmall = 10,
}
for name, size in pairs(FONTS) do
	if rawget(_G, name) == nil then
		rawset(_G, name, { _name = name, GetFont = function() return "Fonts\\FRIZQT__.TTF", size, "" end })
	end
end

-- The client's own words, which cost no translation.
for name, text in pairs({ SEARCH = "Search", CLOSE = "Close", YES = "Yes", NO = "No", ACCEPT = "Accept",
	OKAY = "Okay", CANCEL = "Cancel" }) do
	if rawget(_G, name) == nil then rawset(_G, name, text) end
end
if rawget(_G, "UISpecialFrames") == nil then rawset(_G, "UISpecialFrames", {}) end

-- AceDB's account-wide section, which the window keeps its own state in. In
-- the saved file the way the profile is, so two loads share it like two
-- sessions.
do
	local AceDB = LibStub("AceDB-3.0")
	local new = AceDB.New
	AceDB.New = function(...)
		local db = new(...)
		Mock.sv.global = Mock.sv.global or {}
		db.global = Mock.sv.global
		return db
	end
end

-- The game's Settings window, for the entry IA 1.10 registers: a scenario
-- installs it before loading, and reads back what was registered and asked
-- to open. Put away again with Mock.removeSettings.
function Mock.installSettings()
	local record = { canvases = {}, added = {}, opened = {}, hidden = 0 }
	Mock.settings = record
	rawset(_G, "Settings", {
		RegisterCanvasLayoutCategory = function(frame, name)
			local category = { frame = frame, name = name, ID = 41 }
			category.GetID = function(self) return self.ID end
			record.canvases[#record.canvases + 1] = category
			return category
		end,
		RegisterAddOnCategory = function(category) record.added[#record.added + 1] = category end,
		OpenToCategory = function(id) record.opened[#record.opened + 1] = id end,
	})
	rawset(_G, "SettingsPanel", Mock.newFrame())
	rawset(_G, "HideUIPanel", function(frame)
		if frame == rawget(_G, "SettingsPanel") then record.hidden = record.hidden + 1 end
	end)
	return record
end

function Mock.removeSettings()
	rawset(_G, "Settings", nil)
	rawset(_G, "SettingsPanel", nil)
	rawset(_G, "HideUIPanel", nil)
	Mock.settings = nil
end
