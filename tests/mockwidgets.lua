-- The frames the options window is built from, as the mock answers them: edit
-- boxes, sliders, scroll frames and buttons, and the font objects, the menu
-- and the colour picker they lean on. Loaded by the last lines of mockapi.lua.
--
-- Everything here adds to the frames mockapi.lua makes rather than replacing
-- them, so the protected-call log and every value an older scenario reads back
-- go on working. A method records what it was told wherever a scenario or the
-- renderer has to read it back -- text, a check shown, a slider's value and
-- range, a box's text and focus, a scroll offset -- and the scripts the client
-- fires (OnTextChanged, OnValueChanged, focus, OnShow and OnHide, OnClick) fire
-- here too, with the arguments the client passes them. Without that, a box
-- that commits on Enter and one that never commits read the same to a test.
--
-- Text is measured the way frametree.lua measures it when the renderer has not
-- handed in the real measure: half the font's size a character, counted in
-- characters rather than bytes.

local base = Mock.newFrame
local unpack = table.unpack or unpack

---------------------------------------------------------------------------
-- measuring text
---------------------------------------------------------------------------

local function plainText(text)
	local s = tostring(text or "")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  "):gsub("|A.-|a", "  ")
	return s
end

local function chars(s)
	return #(s:gsub("[\128-\191]", ""))
end

-- An explicit SetFont wins over the font object, as in the client.
local function fontSize(f)
	if f._font then return f._font.size or 12 end
	local obj = f._fontObject
	if type(obj) == "table" and obj.GetFont then return (select(2, obj:GetFont())) or 12 end
	return 12
end

local function eachLine(text)
	return (plainText(text) .. "\n"):gmatch("(.-)\n")
end

local function widest(f)
	local w = 0
	for line in eachLine(f._text) do w = math.max(w, chars(line) * fontSize(f) * 0.5) end
	return w
end

-- Lines as the client would wrap them at the width the string was given:
-- each hard line, cut into as many as its width needs.
local function numLines(f)
	if f._text == nil or f._text == "" then return 0 end
	local width, n = f._width, 0
	for line in eachLine(f._text) do
		local w = chars(line) * fontSize(f) * 0.5
		if width and width > 0 and f._wordWrap ~= false then
			n = n + math.max(1, math.ceil(w / width))
		else
			n = n + 1
		end
	end
	if f._maxLines and f._maxLines > 0 then n = math.min(n, f._maxLines) end
	return n
end

Mock.measureText = widest
Mock.textLines = numLines

-- How tall a box of many lines needs to be for its text, inside its insets.
-- tests/frametree.lua puts its own in, measured as the renderer draws.
function Mock.editTextHeight(f)
	if f._text == nil or f._text == "" then return 0 end
	local ins = f._insets or {}
	local width = (f._width or 0) - (ins[1] or 0) - (ins[2] or 0)
	local size, n = fontSize(f), 0
	for line in eachLine(f._text) do
		local w = chars(line) * size * 0.5
		n = n + (width > 0 and math.max(1, math.ceil(w / width)) or 1)
	end
	return n * size + (n - 1) * (f._spacing or 0) + (ins[3] or 0) + (ins[4] or 0)
end

---------------------------------------------------------------------------
-- the widened frame
---------------------------------------------------------------------------

local function fire(f, script, ...)
	local fn = f.scripts and f.scripts[script]
	if fn then return fn(f, ...) end
end
Mock.fire = fire

local function kindOf(f)
	return f._frameType or f._kind
end

-- Calls through to what was there (the protected-call wrappers above all),
-- then records.
local function after(f, name, record)
	local inner = f[name]
	f[name] = function(self, ...)
		local out = inner and inner(self, ...)
		record(self, ...)
		if out == nil then return self end
		return out
	end
end

local widen

-- The frames that registered for an event, for Mock.frameEvent.
local eventFrames = setmetatable({}, { __mode = "k" })

-- A box of many lines grows to hold its text, as the client's does, so the
-- scroll frame it sits in has something to scroll: the height it was given is
-- the least it is.
local function grow(f)
	if kindOf(f) ~= "EditBox" or not f._multiLine then return end
	f._height = math.max(f._givenHeight or 0, Mock.editTextHeight(f))
end

local function addGeometry(f)
	f.SetClipsChildren = function(self, on) self._clips = on and true or false end
	f.SetToplevel = function(self, on) self._toplevel = on and true or false end
	f.Raise = function(self) self._raised = (self._raised or 0) + 1 end
	f.Lower = function(self) self._lowered = (self._lowered or 0) + 1 end
	f.EnableKeyboard = function(self, on) self._keyboard = on and true or false end
	f.IsKeyboardEnabled = function(self) return self._keyboard == true end
	f.SetPropagateKeyboardInput = function(self, on) self._propagate = on and true or false end
	f.SetHitRectInsets = function(self, l, r, t, b) self._hitRect = { l, r, t, b } end
	f.IsMouseOver = function(self) return self._mouseOver == true end
	after(f, "RegisterEvent", function(self, event)
		self._events = self._events or {}
		self._events[event] = true
		eventFrames[self] = true
	end)
	after(f, "UnregisterEvent", function(self, event)
		if self._events then self._events[event] = nil end
	end)
	after(f, "EnableMouse", function(self, on) self._mouse = on ~= false end)
	after(f, "EnableMouseWheel", function(self, on) self._wheel = on ~= false end)
	-- The size it was given; UIParent keeps the screen the mock describes.
	f.GetWidth = function(self)
		if self == UIParent then return Mock.geometry and Mock.geometry.width or Mock.screenWidth or 1365 end
		return self._width or 0
	end
	local height = f.GetHeight
	f.GetHeight = function(self)
		if self == UIParent then return height(self) end
		return self._height or 0
	end
	f.GetSize = function(self) return self:GetWidth(), self:GetHeight() end
	-- Where it sits, when a scenario models the screen (Mock.geometry) and the
	-- frame hangs off UIParent; otherwise whatever a scenario wrote in.
	local function rect(self)
		if Mock.geometry and self.points and self.points[1] and type(self.points[1][2]) == "table" then
			return Mock.rectUI(self)
		end
		return self._left or 0, self._bottom or 0, self._right or 0, self._top or 0
	end
	f.GetLeft = function(self) return (rect(self)) end
	f.GetBottom = function(self) return select(2, rect(self)) end
	f.GetRight = function(self) return select(3, rect(self)) end
	f.GetTop = function(self) return select(4, rect(self)) end
	f.GetParent = f.GetParent or function(self) return self._parentFrame end
	f.IsVisible = f.IsVisible or function(self)
		local r = self
		while r do
			if r._shown == false then return false end
			r = r._parentFrame
		end
		return true
	end
end

-- OnShow and OnHide when the frame's own shown flag changes, as the client
-- fires them. Wrapped, so a Show on the secure button in combat is still
-- written down by the layer underneath.
local function addVisibility(f)
	local show, hide, shown = f.Show, f.Hide, f.SetShown
	f.Show = function(self, ...)
		local was = self._shown ~= false
		show(self, ...)
		if not was then fire(self, "OnShow") end
		return self
	end
	f.Hide = function(self, ...)
		local was = self._shown ~= false
		hide(self, ...)
		if was then fire(self, "OnHide") end
		return self
	end
	f.SetShown = function(self, on, ...)
		local was = self._shown ~= false
		shown(self, on, ...)
		if was and not on then fire(self, "OnHide") elseif on and not was then fire(self, "OnShow") end
		return self
	end
end

-- The font object is kept apart from an explicit SetFont (`_font`): the
-- renderer maps the object by its `_name`, and an explicit font, set after,
-- wins. GetFont answers with whichever is in force.
local function addText(f)
	f.SetFontObject = function(self, obj)
		self._fontObject, self._font, self._noFont = obj, nil, nil
		if type(obj) == "table" and obj.GetTextColor then self._textColor = { obj:GetTextColor() } end
		return self
	end
	f.GetFontObject = function(self) return self._fontObject end
	local getFont = f.GetFont
	f.GetFont = function(self)
		if not self._font and type(self._fontObject) == "table" and self._fontObject.GetFont then
			return self._fontObject:GetFont()
		end
		return getFont(self)
	end
	f.SetJustifyV = function(self, v) self._justifyV = v end
	f.SetDrawLayer = f.SetDrawLayer or function(self, layer, sub) self._layer, self._sublevel = layer, sub end
	f.SetWordWrap = function(self, on) self._wordWrap = on and true or false end
	f.SetNonSpaceWrap = function(self, on) self._nonSpaceWrap = on and true or false end
	f.SetMaxLines = function(self, n) self._maxLines = n end
	f.SetSpacing = function(self, n) self._spacing = n end
	f.GetStringWidth = f.GetStringWidth or function(self)
		local w = widest(self)
		if self._width and self._width > 0 and self._wordWrap ~= false then return math.min(w, self._width) end
		return w
	end
	f.GetUnboundedStringWidth = f.GetUnboundedStringWidth or function(self) return widest(self) end
	f.GetNumLines = function(self) return numLines(self) end
	f.GetStringHeight = function(self)
		local n = numLines(self)
		if n == 0 then return 0 end
		return n * fontSize(self) + (n - 1) * (self._spacing or 0)
	end
	-- An edit box tells its scripts about every change of text, the
	-- client's own SetText included (userInput false).
	after(f, "SetText", function(self)
		if kindOf(self) == "EditBox" then
			grow(self)
			fire(self, "OnTextChanged", false)
		end
	end)
end

local function addEditBox(f)
	f.SetAutoFocus = function(self, on) self._autoFocus = on and true or false end
	f.SetMultiLine = function(self, on)
		self._multiLine = on and true or false
		grow(self)
	end
	f.IsMultiLine = function(self) return self._multiLine == true end
	f.SetMaxLetters = function(self, n) self._maxLetters = n end
	f.GetNumLetters = function(self) return chars(tostring(self._text or "")) end
	f.SetTextInsets = function(self, l, r, t, b)
		self._insets = { l, r, t, b }
		grow(self)
	end
	after(f, "SetSize", function(self, _, h)
		self._givenHeight = h
		grow(self)
	end)
	after(f, "SetHeight", function(self, h)
		self._givenHeight = h
		grow(self)
	end)
	after(f, "SetWidth", function(self) grow(self) end)
	f.SetCursorPosition = function(self, n) self._cursor = n end
	f.GetCursorPosition = function(self) return self._cursor or 0 end
	f.HighlightText = function(self, from, to) self._highlight = { from or 0, to or -1 } end
	f.HasFocus = function(self) return Mock.focus == self end
	f.SetFocus = function(self)
		if Mock.focus == self then return end
		local was = Mock.focus
		if was then
			Mock.focus = nil
			fire(was, "OnEditFocusLost")
		end
		Mock.focus = self
		fire(self, "OnEditFocusGained")
	end
	f.ClearFocus = function(self)
		if Mock.focus ~= self then return end
		Mock.focus = nil
		fire(self, "OnEditFocusLost")
	end
	f.Insert = function(self, text)
		self._text = tostring(self._text or "") .. tostring(text or "")
		grow(self)
		fire(self, "OnTextChanged", false)
	end
end

local function addButton(f)
	f.IsEnabled = function(self) return self._enabled ~= false end
	f.SetEnabled = function(self, on)
		local was = self._enabled ~= false
		self._enabled = on and true or false
		if was ~= self._enabled then fire(self, self._enabled and "OnEnable" or "OnDisable") end
	end
	f.Enable = function(self) self:SetEnabled(true) end
	f.Disable = function(self) self:SetEnabled(false) end
	after(f, "RegisterForClicks", function(self, ...) self._clicks = { ... } end)
	-- A disabled button ignores the click, as the client's does. With
	-- Mock.secureActions on (tests/mockmacros.lua, "running macros"), a button
	-- made from SecureActionButtonTemplate answers with the client's own
	-- SecureActionButton_OnClick between PreClick and PostClick, as the game's
	-- does; off, as every scenario before it was written, the OnClick script.
	f.Click = function(self, which, down)
		if self._enabled == false then return end
		which = which or "LeftButton"
		fire(self, "PreClick", which, down or false)
		-- Between the two halves of a wrap round it, when it has one
		-- (Mock.wrapClick, "secure handlers" below).
		Mock.wrapClick(self, which, down or false, function(button)
			if Mock.secureActions and self._secureTemplate and Mock.secureOnClick then
				Mock.secureOnClick(self, button, down or false)
			else
				fire(self, "OnClick", button, down or false)
			end
		end)
		fire(self, "PostClick", which, down or false)
	end
end

local function snap(self, v)
	local lo, hi = self._min or 0, self._max or 0
	local step = self._step
	if step and step > 0 and self._obey ~= false then
		v = lo + math.floor((v - lo) / step + 0.5) * step
	end
	return math.max(lo, math.min(hi, v))
end

local function addSlider(f)
	f.SetOrientation = function(self, o) self._orientation = o end
	f.SetMinMaxValues = function(self, lo, hi)
		self._min, self._max = lo, hi
		if self._value ~= nil then self._value = math.max(lo, math.min(hi, self._value)) end
	end
	f.GetMinMaxValues = function(self) return self._min or 0, self._max or 0 end
	f.SetValueStep = function(self, step) self._step = step end
	f.GetValueStep = function(self) return self._step or 0 end
	f.SetObeyStepOnDrag = function(self, on) self._obey = on and true or false end
	f.SetStepsPerPage = function(self, n) self._page = n end
	f.SetValue = function(self, v)
		v = math.max(self._min or v, math.min(self._max or v, v))
		if self._value == v then return end
		self._value = v
		fire(self, "OnValueChanged", v, false)
	end
	f.GetValue = function(self) return self._value or self._min or 0 end
	f.SetThumbTexture = function(self, tex)
		if type(tex) ~= "table" then
			local file = tex
			tex = self:CreateTexture(nil, "OVERLAY")
			tex:SetTexture(file)
		end
		self._thumb = tex
	end
	f.GetThumbTexture = function(self) return self._thumb end
end

local function addScroll(f)
	f.SetScrollChild = function(self, child) self._scrollChild = child end
	f.GetScrollChild = function(self) return self._scrollChild end
	f.GetVerticalScrollRange = function(self)
		local child = self._scrollChild
		return math.max(0, (child and child._height or 0) - (self._height or 0))
	end
	f.SetVerticalScroll = function(self, v)
		self._vscroll = math.max(0, math.min(self:GetVerticalScrollRange(), v or 0))
	end
	f.GetVerticalScroll = function(self) return self._vscroll or 0 end
	f.SetHorizontalScroll = function(self, v) self._hscroll = v end
	f.UpdateScrollChildRect = function(self) self._childRectUpdated = (self._childRectUpdated or 0) + 1 end
end

widen = function(f, frameType, parent)
	if f._widened then return f end
	f._widened = true
	f._frameType = f._frameType or frameType
	f._parentFrame = f._parentFrame or parent
	addGeometry(f)
	addVisibility(f)
	addText(f)
	addEditBox(f)
	addButton(f)
	addSlider(f)
	addScroll(f)
	-- The client refuses to anchor a protected frame (one made from a secure
	-- template) to a region, a font string or a texture: "Action[SetPoint]
	-- failed because[Cannot anchor protected frames to regions]". 1.8.0 hung
	-- each name's secure button off its line of text, which the mock let pass;
	-- in the game it threw inside ApplyStyle on every login.
	local setPoint = f.SetPoint
	f.SetPoint = function(self, point, rel, ...)
		if type(rel) == "table" and type(self._template) == "string" and self._template:find("Secure", 1, true) then
			local kind = rel._frameType or rel._kind
			if kind == "FontString" or kind == "Texture" then
				error(("Action[SetPoint] failed because[Cannot anchor protected frames to regions]: attempted from: %s:SetPoint.")
					:format(tostring(self._name)), 2)
			end
		end
		return setPoint(self, point, rel, ...)
	end
	local makeTexture, makeString = f.CreateTexture, f.CreateFontString
	f.CreateTexture = function(self, ...) return widen(makeTexture(self, ...), "Texture", self) end
	f.CreateFontString = function(self, ...) return widen(makeString(self, ...), "FontString", self) end
	return f
end
Mock.widen = widen

-- tests/frametree.lua takes its frames from here when it is installed, so
-- the recording frames carry all of the above as well.
Mock.newFrame = function() return widen(base()) end

local makeHeader

function CreateFrame(frameType, name, parent, template)
	local f = widen(base(), frameType or "Frame", parent)
	f._name, f._template = name, template
	-- What the client's secure handler and /click need: whether the frame is
	-- a secure action button, and the frame a name finds (GetClickFrame).
	if type(template) == "string" and template:find("SecureActionButtonTemplate", 1, true) then
		f._secureTemplate = true
	end
	-- A header that runs snippets (secure handlers, below).
	if type(template) == "string" and template:find("SecureHandlerStateTemplate", 1, true) then
		makeHeader(f)
	end
	if type(name) == "string" and Mock.namedFrames then Mock.namedFrames[name] = f end
	return f
end
widen(UIParent)

---------------------------------------------------------------------------
-- secure handlers and state drivers
---------------------------------------------------------------------------
--
-- Blizzard's own code (Gethe/wow-ui-source, Interface/AddOns/
-- Blizzard_RestrictedAddOnEnvironment; SecureStateDriver.lua and
-- SecureHandlers.lua read the same on forever, live, classic,
-- classic_anniversary and classic_era, RestrictedFrames.lua differing only in
-- how a forbidden frame is told), as far as a header of
-- SecureHandlerStateTemplate with a state driver needs it:
--
--   RegisterStateDriver(frame, state, values) is RegisterAttributeDriver(frame,
--   "state-" .. state, values). The manager answers at once (resolveDriver on
--   "setstate"), then again every 0.2 s (STATE_DRIVER_UPDATE_THROTTLE) and at
--   once on the next frame after the events it listens for, PLAYER_REGEN_*
--   among them (its OnEvent puts the timer to 0). Here a frame is a call of
--   Mock.runTimers, and the events reach the manager through Mock.frameEvent.
--   It writes the attribute only when the answer changed (resolveDriver: "if
--   newValue ~= oldValue"); "state-visibility" shows or hides the frame
--   instead. Registering is a SetAttribute on the manager, a protected frame,
--   so an addon's call in a fight is refused (written down in
--   Mock.blockedCalls, as the macro calls are).
--
--   The template's OnAttributeChanged runs "_onstate-<id>" with self, stateid
--   and newstate whenever a "state-<id>" attribute is written, from the
--   driver or from the addon's own SetAttribute (SecureHandlers.lua,
--   SecureHandler_StateOnAttributeChanged). A snippet runs in an environment
--   of its own per header, with none of the addon's globals, and frames
--   reach it as handles: GetAttribute, SetAttribute (no name starting "_",
--   only strings, numbers, booleans, nil or a handle), Show and Hide (which
--   write "statehidden" unless told not to), IsShown, IsVisible, GetName and
--   GetFrameRef. A handle acts on a protected frame in a fight, and on an
--   unprotected one only out of one ("Invalid frame handle" otherwise:
--   RestrictedFrames.lua, GetPossiblyForbiddenHandleFrame). What secure code
--   does in a fight is allowed (Mock.secureCode), so it is not one of the
--   addon's protected calls. SetFrameRef is refused in a fight, as the
--   registration is.

local drivers, driverOrder, driverTimer = {}, {}, 0
local DRIVER_THROTTLE = 0.2
local DRIVER_EVENTS = {
	MODIFIER_STATE_CHANGED = true, ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true,
	PLAYER_ENTERING_WORLD = true, UPDATE_SHAPESHIFT_FORM = true, UPDATE_STEALTH = true,
	PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true, PLAYER_REGEN_DISABLED = true,
	PLAYER_REGEN_ENABLED = true, UNIT_PET = true, GROUP_ROSTER_UPDATE = true,
}

-- The mock's own, taken at load: a scenario that counts the addon's pcalls
-- (perf-budget.lua) counts none of these.
local rawpcall = pcall

local function secure(fn, ...)
	local was = Mock.secureCode
	Mock.secureCode = true
	local out = { rawpcall(fn, ...) }
	Mock.secureCode = was
	if not out[1] then error(out[2], 0) end
	return unpack(out, 2)
end

local function isProtectedFrame(f)
	return f._secureTemplate == true or f._secureHeader == true or f._protected == true
end

local handleFrames = setmetatable({}, { __mode = "k" })
local handlesOf = setmetatable({}, { __mode = "k" })

local function handleFrame(handle, any)
	local f = handleFrames[handle]
	if not f then error("Invalid frame handle", 3) end
	if not any and Mock.inCombat and not isProtectedFrame(f) then error("Invalid frame handle", 3) end
	return f
end

local HANDLE = {}
HANDLE.__index = HANDLE
local function handleOf(f)
	local h = handlesOf[f]
	if h then return h end
	h = setmetatable({}, HANDLE)
	handleFrames[h], handlesOf[f] = f, h
	return h
end
Mock.handleOf = handleOf

function HANDLE:GetName() return handleFrame(self, true)._name end
function HANDLE:IsShown() return handleFrame(self, true):IsShown() end
function HANDLE:IsVisible() return handleFrame(self, true):IsVisible() end
function HANDLE:GetAttribute(name)
	local value = handleFrame(self):GetAttribute(name)
	if type(value) == "table" and not handleFrames[value] then return nil end
	return value
end
function HANDLE:GetFrameRef(label)
	if type(label) ~= "string" then return nil end
	local value = handleFrame(self):GetAttribute("frameref-" .. label)
	if type(value) == "table" and handleFrames[value] then return value end
	return nil
end
function HANDLE:SetAttribute(name, value)
	if type(name) ~= "string" or name:match("^_") then error("Invalid attribute name", 2) end
	local tv = type(value)
	if tv ~= "string" and tv ~= "nil" and tv ~= "number" and tv ~= "boolean"
		and not (tv == "table" and handleFrames[value]) then
		error("Invalid attribute value", 2)
	end
	local f = handleFrame(self)
	secure(f.SetAttribute, f, name, value)
end
function HANDLE:Show(skipAttr)
	local f = handleFrame(self)
	secure(f.Show, f)
	if not skipAttr then secure(f.SetAttribute, f, "statehidden", nil) end
end
function HANDLE:Hide(skipAttr)
	local f = handleFrame(self)
	secure(f.Hide, f)
	if not skipAttr then secure(f.SetAttribute, f, "statehidden", true) end
end

-- What a snippet may call: none of the addon's globals, nor print, nor the
-- frames by name.
local RESTRICTED = {
	type = type, tostring = tostring, tonumber = tonumber, select = select,
	string = string, math = math, table = table,
	format = string.format, strmatch = string.match, strfind = string.find,
	newtable = function(...) return { ... } end,
	SecureCmdOptionParse = function(...) return SecureCmdOptionParse(...) end,
}

local function runSnippet(header, body, names, ...)
	local fn, err = loadstring("local " .. names .. " = ...\n" .. body, "=snippet")
	if not fn then error("snippet does not compile: " .. tostring(err), 0) end
	header._snippetEnv = header._snippetEnv or setmetatable({}, { __index = RESTRICTED })
	setfenv(fn, header._snippetEnv)
	Mock.snippetRuns = (Mock.snippetRuns or 0) + 1
	return secure(fn, handleOf(header), ...)
end
Mock.runSnippet = runSnippet

makeHeader = function(f)
	f._secureHeader = true
	f._protected = true
	f.IsProtected = function() return true, true end
	local set = f.SetAttribute
	f.SetAttribute = function(self, name, value)
		set(self, name, value)
		local stateid = type(name) == "string" and name:match("^state%-(.+)")
		if stateid then
			local body = self:GetAttribute("_onstate-" .. stateid)
			if type(body) == "string" then runSnippet(self, body, "self, stateid, newstate", stateid, value) end
		end
		return self
	end
	f.SetFrameRef = function(self, label, ref)
		if Mock.inCombat then
			Mock.blockedCalls[#Mock.blockedCalls + 1] = "SetFrameRef"
			return
		end
		self.attributes["frameref-" .. tostring(label)] = handleOf(ref)
	end
	f.Execute = function(self, body)
		if Mock.inCombat then
			Mock.blockedCalls[#Mock.blockedCalls + 1] = "Execute"
			return
		end
		return runSnippet(self, body, "self")
	end
end
Mock.makeSecureHeader = makeHeader

-- SecureHandlerWrapScript(frame, script, header, preBody, postBody), as far as
-- a wrap round a button's OnClick needs it (SecureHandlers.lua, the same on
-- every client: SecureHandlerWrapScript at line 602 on forever, Wrapped_Click
-- at 272). The header must be explicitly protected and the pre-body a string;
-- an addon's call in a fight is refused, as every call on the API frame is.
-- A click then runs the pre-body in the header's environment with `self` the
-- wrapped frame's handle and `control` the header's, which answers a button
-- (false stops the click, another name replaces it) and a message; then the
-- click itself; then, when there was a message, the post-body.
function SecureHandlerWrapScript(frame, script, header, preBody, postBody)
	if Mock.inCombat then
		Mock.blockedCalls[#Mock.blockedCalls + 1] = "SecureHandlerWrapScript"
		return
	end
	if type(frame) ~= "table" or type(frame.SetAttribute) ~= "function" then error("Invalid frame", 2) end
	if type(script) ~= "string" then error("Invalid script id", 2) end
	if not (type(header) == "table" and header._secureHeader) then error("Header frame must be explicitly protected", 2) end
	if type(preBody) ~= "string" then error("Invalid pre-handler body", 2) end
	if postBody ~= nil and type(postBody) ~= "string" then error("Invalid post-handler body", 2) end
	frame._wraps = frame._wraps or {}
	frame._wraps[script] = { header = header, pre = preBody, post = postBody }
end

local function runWrap(header, frame, body, names, ...)
	local fn, err = loadstring("local control, " .. names .. " = ...\n" .. body, "=snippet")
	if not fn then error("snippet does not compile: " .. tostring(err), 0) end
	header._snippetEnv = header._snippetEnv or setmetatable({}, { __index = RESTRICTED })
	setfenv(fn, header._snippetEnv)
	Mock.snippetRuns = (Mock.snippetRuns or 0) + 1
	return secure(fn, handleOf(header), handleOf(frame), ...)
end

-- One click of `frame` as Wrapped_Click runs it: `action(button)` is the
-- click itself. With no wrap, the action alone.
function Mock.wrapClick(frame, which, down, action)
	local wrap = frame._wraps and frame._wraps.OnClick
	local newbutton, message
	if wrap then
		newbutton, message = runWrap(wrap.header, frame, wrap.pre, "self, button, down", which, down)
		if newbutton == false then return end
		if newbutton then which = tostring(newbutton) end
	end
	if action then action(which) end
	if wrap and wrap.post and message ~= nil then
		runWrap(wrap.header, frame, wrap.post, "self, message, button, down", message, which, down)
	end
end

local function resolveDriver(frame, attribute, values)
	local newValue = SecureCmdOptionParse(values)
	if attribute == "state-visibility" then
		if newValue == "show" then
			secure(frame.Show, frame)
			secure(frame.SetAttribute, frame, "statehidden", nil)
		elseif newValue == "hide" then
			secure(frame.Hide, frame)
			secure(frame.SetAttribute, frame, "statehidden", true)
		end
	elseif newValue then
		if newValue == "nil" then newValue = nil else newValue = tonumber(newValue) or newValue end
		if newValue ~= frame:GetAttribute(attribute) then secure(frame.SetAttribute, frame, attribute, newValue) end
	end
end

function RegisterAttributeDriver(frame, attribute, values)
	if not (attribute and values and attribute:sub(1, 1) ~= "_") then return end
	if Mock.inCombat then
		Mock.blockedCalls[#Mock.blockedCalls + 1] = "RegisterAttributeDriver"
		return
	end
	if not drivers[frame] then
		drivers[frame] = {}
		driverOrder[#driverOrder + 1] = frame
	end
	if values == "" then
		drivers[frame][attribute] = nil
	else
		drivers[frame][attribute] = values
		resolveDriver(frame, attribute, values)
	end
end
function UnregisterAttributeDriver(frame, attribute)
	if Mock.inCombat then
		Mock.blockedCalls[#Mock.blockedCalls + 1] = "UnregisterAttributeDriver"
		return
	end
	if attribute then
		if drivers[frame] then drivers[frame][attribute] = nil end
	else
		drivers[frame] = nil
	end
end
function RegisterStateDriver(frame, state, values) RegisterAttributeDriver(frame, "state-" .. state, values) end
function UnregisterStateDriver(frame, state) UnregisterAttributeDriver(frame, "state-" .. state) end

-- What the driver of a frame's attribute reads, for a scenario to ask.
function Mock.driverFor(frame, attribute)
	return drivers[frame] and drivers[frame][attribute] or nil
end

-- One frame of the manager's OnUpdate, `elapsed` seconds after the last.
function Mock.stateDriverFrame(elapsed)
	driverTimer = driverTimer - (elapsed or 0)
	if driverTimer > 0 then return false end
	driverTimer = DRIVER_THROTTLE
	for _, frame in ipairs(driverOrder) do
		local list = drivers[frame]
		if list then
			local attributes = {}
			for attribute in pairs(list) do attributes[#attributes + 1] = attribute end
			table.sort(attributes)
			for _, attribute in ipairs(attributes) do
				if list[attribute] then resolveDriver(frame, attribute, list[attribute]) end
			end
		end
	end
	return true
end

do
	local runTimers = Mock.runTimers
	function Mock.runTimers(seconds)
		local done = runTimers(seconds)
		Mock.stateDriverFrame(seconds or 0)
		return done
	end
end

-- A click of the mouse on a frame, as the client delivers it: a down click if
-- the frame is registered for one, then an up click if it is registered for
-- that. No isKeyPress and no isSecureAction reach an addon's button (Blizzard's
-- SecureTemplates.xml), so nothing else rides along. A frame that was never
-- registered answers the left button's up, the client's default.
function Mock.mouseClickOn(frame, which)
	which = which or "LeftButton"
	local clicks = frame._clicks or { "LeftButtonUp" }
	local function registered(phase)
		for _, c in ipairs(clicks) do
			if c == "Any" .. phase or c == which .. phase then return true end
		end
		return false
	end
	if registered("Down") then frame:Click(which, true) end
	if registered("Up") then frame:Click(which, false) end
end

-- A key bound to "CLICK Name:Button" pressed: the down click, and with
-- `opts.release` the up click the key's release sends.
function Mock.pressBinding(command, opts)
	local name, which = tostring(command):match("^CLICK ([^:]+):(.+)$")
	local frame = name and Mock.namedFrames and Mock.namedFrames[name]
	if not frame then return false end
	frame:Click(which, true)
	if opts and opts.release then frame:Click(which, false) end
	return true
end

---------------------------------------------------------------------------
-- driving the frames as a player would
---------------------------------------------------------------------------

-- Typed into: the box takes the focus, and its text changes with userInput
-- true, which is how OnTextChanged tells a player from the addon.
function Mock.type(box, text)
	box:SetFocus()
	box._text = text
	box._cursor = chars(tostring(text))
	grow(box)
	fire(box, "OnTextChanged", true)
end

-- An event as the client hands it to the frames that registered for it with
-- RegisterEvent (Core's own come through AceEvent, and scenarios call those
-- handlers directly). Answers how many frames heard it.
function Mock.frameEvent(event, ...)
	-- The state driver manager listens too: its next frame answers at once.
	if DRIVER_EVENTS[event] then driverTimer = 0 end
	local heard = 0
	for f in pairs(eventFrames) do
		local fn = f._events and f._events[event] and f.scripts and f.scripts.OnEvent
		if fn then
			fn(f, event, ...)
			heard = heard + 1
		end
	end
	return heard
end

-- A key pressed in a focused box: "ENTER", "ESCAPE", "TAB", or an arrow
-- ("UP", "DOWN"), each through the script the client fires for it.
function Mock.press(box, key)
	if key == "ENTER" then return fire(box, "OnEnterPressed") end
	if key == "ESCAPE" then return fire(box, "OnEscapePressed") end
	if key == "TAB" then return fire(box, "OnTabPressed") end
	return fire(box, "OnArrowPressed", key)
end

-- A key reaching a frame that took the keyboard; false when it did not.
function Mock.keyDown(frame, key)
	if frame._keyboard ~= true then return false end
	fire(frame, "OnKeyDown", key)
	return true
end

-- The buttons held, as IsMouseButtonDown reports them: the client knows a
-- button is up even when the frame it went down on never hears about it.
function Mock.mouseDown(frame, which)
	Mock.buttonsDown[which or "LeftButton"] = true
	fire(frame, "OnMouseDown", which or "LeftButton")
end
function Mock.mouseUp(frame, which)
	Mock.buttonsDown[which or "LeftButton"] = nil
	fire(frame, "OnMouseUp", which or "LeftButton")
end
function IsMouseButtonDown(which)
	return Mock.buttonsDown[which or "LeftButton"] == true
end

-- The thumb dragged to `value`, snapped as the client snaps it with
-- SetObeyStepOnDrag on.
function Mock.drag(slider, value)
	local v = snap(slider, value)
	if slider._value == v then return end
	slider._value = v
	fire(slider, "OnValueChanged", v, true)
end

-- Shift, Ctrl and Alt, held or not.
function IsShiftKeyDown() return Mock.modifiers.shift == true end
function IsControlKeyDown() return Mock.modifiers.ctrl == true end
function IsAltKeyDown() return Mock.modifiers.alt == true end

---------------------------------------------------------------------------
-- font objects and the client's own words
---------------------------------------------------------------------------

local FRIZ = "Fonts\\FRIZQT__.TTF"
local function fontObject(name, size, r, g, b)
	return {
		_name = name,
		GetName = function() return name end,
		GetFont = function() return FRIZ, size, "" end,
		GetTextColor = function() return r, g, b, 1 end,
	}
end
GameFontNormal = fontObject("GameFontNormal", 12, 1, 0.82, 0)
GameFontNormalLarge = fontObject("GameFontNormalLarge", 16, 1, 0.82, 0)
GameFontNormalSmall = fontObject("GameFontNormalSmall", 10, 1, 0.82, 0)
GameFontHighlight = fontObject("GameFontHighlight", 12, 1, 1, 1)
GameFontHighlightSmall = fontObject("GameFontHighlightSmall", 10, 1, 1, 1)
GameFontDisable = fontObject("GameFontDisable", 12, 0.5, 0.5, 0.5)
GameFontDisableSmall = fontObject("GameFontDisableSmall", 10, 0.5, 0.5, 0.5)

YES, NO, ACCEPT, CLOSE = "Yes", "No", "Accept", "Close"
SEARCH, OKAY, CANCEL = "Search", "Okay", "Cancel"
NOT_BOUND = "Not Bound"

---------------------------------------------------------------------------
-- the menu
---------------------------------------------------------------------------

-- A context menu in the shape MenuUtil hands its generator: every entry is a
-- description that can hold entries of its own. Mock.menu is the last one
-- opened, so a scenario can read what was offered and pick an entry.
local function description(kind, text, a, b, data)
	local d = { kind = kind, text = text, entries = {}, enabled = true }
	if kind == "radio" or kind == "checkbox" then
		d.isSelected, d.setSelected, d.data = a, b, data
	else
		d.fn, d.data = a, data
	end
	local function add(entry)
		d.entries[#d.entries + 1] = entry
		return entry
	end
	function d:CreateTitle(t) return add(description("title", t)) end
	function d:CreateDivider() return add(description("divider")) end
	function d:CreateSpacer() return add(description("spacer")) end
	function d:CreateButton(t, fn, value) return add(description("button", t, fn, nil, value)) end
	function d:CreateRadio(t, isSelected, setSelected, value)
		return add(description("radio", t, isSelected, setSelected, value))
	end
	function d:CreateCheckbox(t, isSelected, setSelected, value)
		return add(description("checkbox", t, isSelected, setSelected, value))
	end
	function d:SetEnabled(on) self.enabled = on ~= false end
	function d:SetTooltip(fn) self.tooltip = fn end
	-- The tallest the menu draws before it scrolls; a menu never given one
	-- runs on past the screen's edge.
	function d:SetScrollMode(extent)
		assert(type(extent) == "number", "SetScrollMode takes a number")
		self.scrollExtent = extent
	end
	return d
end

local installedMenu

-- MenuUtil for the length of a scenario. Not there by default: the launcher
-- opens a menu on a right-click wherever MenuUtil exists and throws the switch
-- where it does not, and the scenarios written before this one are about the
-- switch. Mock.reset takes it away again, unless a scenario has put its own in.
function Mock.useMenu()
	installedMenu = {
		CreateContextMenu = function(owner, generator)
			local root = description("root")
			generator(owner, root)
			Mock.menu = { owner = owner, root = root, entries = root.entries }
			Mock.menus = (Mock.menus or 0) + 1
			Mock.menuOpen, Mock.menuResponse = true, nil
			return root
		end,
	}
	MenuUtil = installedMenu
	return installedMenu
end

-- Every entry of the last menu, depth first.
function Mock.menuEntries(root)
	local out = {}
	local function walk(d)
		for _, e in ipairs(d.entries) do
			out[#out + 1] = e
			walk(e)
		end
	end
	if root or Mock.menu then walk(root or Mock.menu.root) end
	return out
end

-- The entry of the last menu whose text is `text`, or nil.
function Mock.menuEntry(text)
	for _, e in ipairs(Mock.menuEntries()) do
		if e.text == text then return e end
	end
	return nil
end

-- Whether a radio or checkbox entry shows as chosen.
function Mock.menuChosen(text)
	local e = Mock.menuEntry(text)
	return e ~= nil and e.isSelected ~= nil and e.isSelected(e.data) == true
end

-- Clicks an entry of the last menu; false when there is none by that text.
-- What the entry's callback answered is its response, as the client's menu
-- reads it: nothing (or MenuResponse.CloseAll) shuts the menu, anything else
-- leaves it open on the entries it was built with. Mock.menuOpen says which.
function Mock.pickMenu(text)
	local e = Mock.menuEntry(text)
	if not e or e.enabled == false then return false end
	local response
	if e.setSelected then response = e.setSelected(e.data) elseif e.fn then response = e.fn(e.data) end
	local closeAll = type(MenuResponse) == "table" and MenuResponse.CloseAll or nil
	Mock.menuResponse = response
	Mock.menuOpen = not (response == nil or (closeAll ~= nil and response == closeAll))
	return true
end

---------------------------------------------------------------------------
-- the colour picker
---------------------------------------------------------------------------

local function newColourPicker()
	local f = CreateFrame("Frame", "ColorPickerFrame", UIParent)
	f._shown = false
	f.SetupColorPickerAndShow = function(self, info)
		self._info = info
		self._r, self._g, self._b = info.r or 1, info.g or 1, info.b or 1
		self._a = info.hasOpacity and (info.opacity or 1) or 1
		self._previous = { r = self._r, g = self._g, b = self._b, a = self._a }
		self:Show()
	end
	f.GetColorRGB = function(self) return self._r, self._g, self._b end
	f.GetColorAlpha = function(self) return self._a end
	f.GetPreviousValues = function(self)
		local p = self._previous or {}
		return p.r, p.g, p.b, p.a
	end
	return f
end

-- The player moving the picker to a colour, which the client reports through
-- swatchFunc and, for the opacity, opacityFunc.
function Mock.pickColour(r, g, b, a)
	local f = ColorPickerFrame
	local info = f._info or {}
	f._r, f._g, f._b = r, g, b
	if a ~= nil then f._a = a end
	if info.swatchFunc then info.swatchFunc() end
	if a ~= nil and info.opacityFunc then info.opacityFunc() end
end

-- Okay (true) or Cancel (false). Cancel hands cancelFunc the colour the
-- picker opened on, as the client does.
function Mock.closeColour(accept)
	local f = ColorPickerFrame
	local info = f._info or {}
	if not accept and info.cancelFunc then info.cancelFunc(f._previous) end
	f:Hide()
end

---------------------------------------------------------------------------
-- put back by Mock.reset
---------------------------------------------------------------------------

local function install()
	Mock.namedFrames = {}
	Mock.modifiers = {}
	Mock.buttonsDown = {}
	Mock.menu, Mock.menus, Mock.focus = nil, 0, nil
	Mock.menuOpen, Mock.menuResponse = false, nil
	for f in pairs(eventFrames) do eventFrames[f] = nil end
	-- No driver outlives its scenario.
	for f in pairs(drivers) do drivers[f] = nil end
	for i = #driverOrder, 1, -1 do driverOrder[i] = nil end
	-- Each maps one half of a pair to the other, and Lua 5.1 holds a weak-keyed
	-- table's values strongly, so together they would keep every frame ever
	-- handed a handle, and through it every addon the run loaded.
	for h in pairs(handleFrames) do handleFrames[h] = nil end
	for f in pairs(handlesOf) do handlesOf[f] = nil end
	driverTimer = 0
	Mock.secureCode, Mock.snippetRuns, Mock.affectingCombat = nil, 0, nil
	Mock.screenWidth = 1365
	if installedMenu and rawget(_G, "MenuUtil") == installedMenu then MenuUtil = nil end
	installedMenu = nil
	ColorPickerFrame = newColourPicker()
end

local reset = Mock.reset
function Mock.reset()
	reset()
	install()
end
install()
