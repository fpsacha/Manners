-- What the mock's frames were told, kept as a tree.
--
-- The mock in mockapi.lua answers every drawing call and remembers only the
-- handful a scenario has needed to read back: text, alpha, a colour, a size.
-- That is enough to assert on and nowhere near enough to draw, and the prompt's
-- look is a thing nobody here can run the game to see. So this wraps the
-- mock's frames rather than replacing them: every frame, texture, font string,
-- animation group and cooldown the addon makes is recorded with its parent,
-- its layer and everything it was told, and the calls still go through to the
-- mock underneath -- including the wrappers that write down a protected call
-- made in combat, which a replacement would have silently dropped.
--
-- Used three ways. tools/render_prompt.py walks the tree and draws it,
-- tests/scenarios/look.lua asks which animations are playing, which is the only
-- evidence that an effect starts and stops: against the mock's own groups,
-- whose IsPlaying always answers false, a pulse that never stops and one that
-- never starts are the same pulse. And tools/render_options.py draws the
-- options window from it, which is built of edit boxes, sliders and scroll
-- frames as well, and measures its text to lay itself out (see "Widgets" and
-- "Text and geometry" below).
--
-- Nothing here is loaded by the addon, and nothing here changes what the mock
-- does for a scenario that does not ask for it: FrameTree.install() swaps
-- CreateFrame for a recording one, and FrameTree.uninstall() puts the mock's
-- own back.

FrameTree = FrameTree or {}
local FT = FrameTree

local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
FT.LAYERS = LAYERS

-- Every region ever made, in the order it was made. The draw order within one
-- frame and one layer is creation order, as it is in the client.
FT.all = {}
FT.serial = 0
-- Each Play and Stop, in order, as { what, group }. A scenario asks whether a
-- group started or stopped between two points in time by counting here.
FT.log = {}

local base

local function note(what, group)
	FT.log[#FT.log + 1] = { what = what, group = group, at = GetTime() }
end

-- A method that records its arguments under `key` and then calls whatever the
-- mock had in that slot, so the mock's own bookkeeping -- the protected-call
-- list above all -- still sees the call.
local function wrap(obj, name, record)
	local inner = obj[name]
	obj[name] = function(self, ...)
		record(self, ...)
		if inner then return inner(self, ...) end
		return self
	end
end

local instrument

local function newAnimation(group, kind)
	local a = { _kind = kind or "Animation", _group = group, _order = 1, _duration = 0,
		_startDelay = 0, scripts = {} }
	a.SetFromAlpha = function(self, v) self._fromAlpha = v return self end
	a.SetToAlpha = function(self, v) self._toAlpha = v return self end
	a.SetDuration = function(self, v) self._duration = v return self end
	a.GetDuration = function(self) return self._duration end
	a.SetOrder = function(self, v) self._order = v return self end
	a.SetOffset = function(self, x, y) self._offset = { x or 0, y or 0 } return self end
	a.SetSmoothing = function(self, v) self._smoothing = v return self end
	a.SetStartDelay = function(self, v) self._startDelay = v return self end
	a.SetScaleFrom = function(self, x, y) self._scaleFrom = { x, y } return self end
	a.SetScaleTo = function(self, x, y) self._scaleTo = { x, y } return self end
	a.SetFromScale = a.SetScaleFrom
	a.SetToScale = a.SetScaleTo
	a.SetOrigin = function(self, point, x, y) self._origin = { point, x or 0, y or 0 } return self end
	a.SetDegrees = function(self, v) self._degrees = v return self end
	a.SetTarget = function(self, t) self._target = t return self end
	a.SetChildKey = function(self, k) self._childKey = k return self end
	a.SetScript = function(self, which, fn) self.scripts[which] = fn return self end
	a.GetScript = function(self, which) return self.scripts[which] end
	a.Play = function(self) return self end
	a.Stop = function(self) return self end
	return a
end

local function newGroup(owner)
	local g = { _kind = "AnimationGroup", _owner = owner, _anims = {}, _playing = false,
		_plays = 0, _stops = 0, scripts = {} }
	FT.serial = FT.serial + 1
	g._serial = FT.serial
	g.CreateAnimation = function(self, kind)
		local a = newAnimation(self, kind)
		self._anims[#self._anims + 1] = a
		return a
	end
	g.SetLooping = function(self, how) self._looping = how return self end
	g.GetLooping = function(self) return self._looping or "NONE" end
	g.SetToFinalAlpha = function(self, v) self._toFinal = v and true or false return self end
	g.SetScript = function(self, which, fn) self.scripts[which] = fn return self end
	g.GetScript = function(self, which) return self.scripts[which] end
	g.HookScript = function(self, which, fn)
		local prior = self.scripts[which]
		self.scripts[which] = prior and function(...) prior(...) return fn(...) end or fn
		return self
	end
	g.Play = function(self)
		-- Play on a group already playing restarts it in the client only after a
		-- Stop; on its own it carries on. Counted either way, because a play
		-- asked for is what the scenarios check.
		self._plays = self._plays + 1
		if not self._playing then self._startedAt = GetTime() end
		self._playing = true
		note("play", self)
		if self.scripts.OnPlay then self.scripts.OnPlay(self) end
		return self
	end
	g.Restart = function(self)
		self._playing = false
		return self:Play()
	end
	g.Stop = function(self)
		local was = self._playing
		self._playing = false
		self._stops = self._stops + 1
		note("stop", self)
		if was and self.scripts.OnStop then self.scripts.OnStop(self, true) end
		return self
	end
	g.Finish = function(self) return FT.finishGroup(self) end
	g.IsPlaying = function(self) return self._playing end
	g.IsDone = function(self) return not self._playing end
	g.GetAnimations = function(self) return (table.unpack or unpack)(self._anims) end
	g.GetParent = function(self) return self._owner end
	owner._groups = owner._groups or {}
	owner._groups[#owner._groups + 1] = g
	return g
end

-- How long one pass of a group takes: its orders run one after another, and the
-- animations sharing an order run together.
function FT.groupLength(g)
	local byOrder = {}
	for _, a in ipairs(g._anims) do
		local len = (a._startDelay or 0) + (a._duration or 0)
		byOrder[a._order] = math.max(byOrder[a._order] or 0, len)
	end
	local total = 0
	for _, len in pairs(byOrder) do total = total + len end
	return total
end

function FT.finishGroup(g)
	if not g._playing then return end
	g._playing = false
	note("finish", g)
	if g.scripts.OnFinished then g.scripts.OnFinished(g, false) end
end

-- Let the clock reach the animations. Every one-shot group that has run its
-- length since it started is finished, and its OnFinished runs, which is the
-- only thing that moves a flash back to invisible. A looping group never
-- finishes on its own, which is exactly what a scenario asks about it.
function FT.settle()
	local now = GetTime()
	for _, g in ipairs(FT.groups()) do
		if g._playing and (g._looping == nil or g._looping == "NONE")
			and now - (g._startedAt or now) >= FT.groupLength(g) then
			FT.finishGroup(g)
		end
	end
end

function FT.groups()
	local out = {}
	for _, r in ipairs(FT.all) do
		for _, g in ipairs(r._groups or {}) do out[#out + 1] = g end
	end
	return out
end

-- Every group playing right now, and the looping ones among them. Those are the
-- only thing that costs anything while nothing is happening.
function FT.playing()
	local all, looping = {}, {}
	for _, g in ipairs(FT.groups()) do
		if g._playing then
			all[#all + 1] = g
			if g._looping and g._looping ~= "NONE" then looping[#looping + 1] = g end
		end
	end
	return all, looping
end

-- Whether a region is on screen as far as the tree can tell: it and every
-- frame above it shown.
function FT.visible(r)
	while r do
		if r._shown == false then return false end
		r = r._parent
	end
	return true
end

-- How wide a line of text is. The renderer hands in FT.measure, which asks the
-- font it draws with, so a line the addon shrank to fit is the line the
-- picture shows fitting. Without it, half the font's size a character --
-- Friz Quadrata's average, near enough -- counted in characters rather than
-- bytes, or every Cyrillic or accented line measured twice its width.
local function measure(text, size)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if FT.measure then return FT.measure(text, size) end
	local chars = text:gsub("[\128-\191]", "")
	return #chars * size * 0.5
end

-- ------------------------------------------------------------------ widgets
--
-- The options window is built of Frame, Button, EditBox, Slider and
-- ScrollFrame, its text set in the game's font objects. What each of those is
-- told is kept in `_ft`, apart from the fields the mock keeps for itself, so a
-- mock that records the same call its own way cannot disagree with what is
-- drawn. Setters go through to the mock as every other call here does; a
-- getter is only supplied where the mock has none.

local FRIZ = "Fonts\\FRIZQT__.TTF"
local GOLD, WHITE, GREY = { 1, 0.82, 0, 1 }, { 1, 1, 1, 1 }, { 0.5, 0.5, 0.5, 1 }
-- The client's own: Normal is gold, Highlight white, Disable grey, each at
-- 12, with Large at 16 and Small at 10.
FT.FONTS = {
	GameFontNormal = { FRIZ, 12, GOLD }, GameFontNormalLarge = { FRIZ, 16, GOLD },
	GameFontNormalSmall = { FRIZ, 10, GOLD }, GameFontHighlight = { FRIZ, 12, WHITE },
	GameFontHighlightSmall = { FRIZ, 10, WHITE }, GameFontDisable = { FRIZ, 12, GREY },
	GameFontDisableSmall = { FRIZ, 10, GREY },
}

-- A colour set by SetTextColor and one that came with a font object are both
-- kept, stamped, and the later one is what is drawn.
local function stamp()
	FT.stamps = (FT.stamps or 0) + 1
	return FT.stamps
end

-- A font object's name, face and colour. The object is a table (the client's,
-- or the mock's with `_name` and GetFont) or its global's name.
local function fontObject(obj)
	local name = type(obj) == "string" and obj or (type(obj) == "table" and obj._name) or nil
	if type(obj) == "string" then obj = _G[obj] end
	local known = name and FT.FONTS[name]
	local path, size, flags
	if type(obj) == "table" and type(obj.GetFont) == "function" then path, size, flags = obj:GetFont() end
	if not size and known then path, size, flags = known[1], known[2], "" end
	local color = known and known[3]
	if not color and type(obj) == "table" and type(obj.GetTextColor) == "function" then
		color = { obj:GetTextColor() }
	end
	return name, size and { path = path, size = size, flags = flags } or nil, color
end

local function utf8len(s)
	return select(2, tostring(s or ""):gsub("[^\128-\191]", ""))
end

-- Moved under another frame without going through the mock's SetParent: a
-- scroll child belongs to its scroll frame once it is set, as in the client.
local function adopt(parent, child)
	local old = child._parent
	if old == parent then return end
	if old and old._children then
		for i, c in ipairs(old._children) do
			if c == child then table.remove(old._children, i) break end
		end
	end
	child._parent = parent
	if parent._children then parent._children[#parent._children + 1] = child end
	if parent._level and child._level then FT.relevel(child, parent._level + 1) end
end

-- A frame's level set, and everything on it moved by as much, so what was
-- drawn over it still is.
function FT.relevel(f, level)
	local delta = level - (f._level or level)
	if delta == 0 then return end
	local function shift(r)
		if r._level then r._level = r._level + delta end
		for _, c in ipairs(r._children or {}) do shift(c) end
	end
	shift(f)
end

local W = {}

-- Font strings and edit boxes.
function W.text(f)
	wrap(f, "SetFontObject", function(self, obj)
		local name, font, color = fontObject(obj)
		local w = self._ft
		w.fontObject, w.fontRef, w.objColor, w.objAt = name, obj, color, stamp()
		if font then self._font, self._noFont = font, nil end
	end)
	if not f.GetFontObject then f.GetFontObject = function(self) return self._ft.fontRef end end
	wrap(f, "SetTextColor", function(self) self._ft.colorAt = stamp() end)
	wrap(f, "SetSpacing", function(self, v) self._ft.spacing = tonumber(v) end)
	if not f.GetSpacing then f.GetSpacing = function(self) return self._ft.spacing or 0 end end
end

function W.FontString(f)
	W.text(f)
	-- The field tools/render_ledger.lua's measurable strings write as well.
	wrap(f, "SetMaxLines", function(self, n) self._maxLines = tonumber(n) end)
	if not f.GetMaxLines then f.GetMaxLines = function(self) return self._maxLines or 0 end end
	wrap(f, "SetNonSpaceWrap", function(self, v) self._ft.nonSpaceWrap = v and true or false end)
	-- Answered from the same lines the renderer draws, as the width is.
	f.GetStringHeight = function(self) return FT.textHeight(self) end
	f.GetNumLines = function(self) return #(FT.textLines(self)) end
end

-- Enabled and disabled, for buttons, sliders and edit boxes alike.
function W.enable(f)
	wrap(f, "Enable", function(self) self._ft.enabled = true end)
	wrap(f, "Disable", function(self) self._ft.enabled = false end)
	wrap(f, "SetEnabled", function(self, v) self._ft.enabled = v and true or false end)
	if not f.IsEnabled then f.IsEnabled = function(self) return self._ft.enabled ~= false end end
end

function W.Button(f)
	W.enable(f)
	if not f.Click then
		f.Click = function(self, button, down)
			local fn = self.scripts and self.scripts.OnClick
			if fn and self._ft.enabled ~= false then fn(self, button or "LeftButton", down or false) end
		end
	end
end

function W.EditBox(f)
	W.text(f)
	W.enable(f)
	wrap(f, "SetMultiLine", function(self, v) self._ft.multiLine = v and true or false end)
	wrap(f, "SetTextInsets", function(self, l, r, t, b)
		self._ft.insets = { tonumber(l) or 0, tonumber(r) or 0, tonumber(t) or 0, tonumber(b) or 0 }
	end)
	wrap(f, "SetMaxLetters", function(self, n) self._ft.maxLetters = tonumber(n) end)
	wrap(f, "SetAutoFocus", function(self, v) self._ft.autoFocus = v and true or false end)
	-- One box has the keyboard at a time.
	wrap(f, "SetFocus", function(self)
		if FT.focus and FT.focus ~= self and FT.focus._ft then FT.focus._ft.focus = false end
		FT.focus, self._ft.focus = self, true
	end)
	wrap(f, "ClearFocus", function(self)
		if FT.focus == self then FT.focus = nil end
		self._ft.focus = false
	end)
	wrap(f, "SetCursorPosition", function(self, n) self._ft.cursor = tonumber(n) end)
	if not f.HighlightText then f.HighlightText = function(self) return self end end
	if not f.HasFocus then f.HasFocus = function(self) return self._ft.focus == true end end
	if not f.GetNumLetters then f.GetNumLetters = function(self) return utf8len(self._text) end end
	if not f.Insert then
		f.Insert = function(self, s) return self:SetText(tostring(self._text or "") .. tostring(s or "")) end
	end
end

local function clampValue(w)
	if w.value ~= nil and w.min and w.max then w.value = math.max(w.min, math.min(w.max, w.value)) end
end

-- The thumb is a texture of the slider's, given or made from a file. The
-- client puts it where the value says, whatever anchors it was given.
local function setThumb(slider, tex)
	local w = slider._ft
	local thumb = type(tex) == "table" and tex._kind and tex
	if not thumb then
		thumb = w.thumb and w.thumb._ft.madeHere and w.thumb or slider:CreateTexture(nil, "ARTWORK")
		thumb._ft.madeHere = true
		thumb:SetTexture(tex)
	end
	if w.thumb and w.thumb ~= thumb then w.thumb._ft.thumbOf = nil end
	thumb._ft.thumbOf, w.thumb = slider, thumb
end

function W.Slider(f)
	W.enable(f)
	wrap(f, "SetOrientation", function(self, o) self._ft.orientation = o end)
	wrap(f, "SetMinMaxValues", function(self, lo, hi)
		self._ft.min, self._ft.max = tonumber(lo), tonumber(hi)
		clampValue(self._ft)
	end)
	wrap(f, "SetValueStep", function(self, v) self._ft.step = tonumber(v) end)
	wrap(f, "SetObeyStepOnDrag", function(self, v) self._ft.obeyStep = v and true or false end)
	wrap(f, "SetValue", function(self, v)
		self._ft.value = tonumber(v)
		clampValue(self._ft)
	end)
	if not f.GetValue then f.GetValue = function(self) return self._ft.value or self._ft.min or 0 end end
	if not f.GetMinMaxValues then
		f.GetMinMaxValues = function(self) return self._ft.min or 0, self._ft.max or 0 end
	end
	if not f.GetValueStep then f.GetValueStep = function(self) return self._ft.step or 0 end end
	wrap(f, "SetThumbTexture", setThumb)
	-- Always this one: the window sizes and colours the thumb it is handed back.
	f.GetThumbTexture = function(self) return self._ft.thumb end
end

function W.ScrollFrame(f)
	wrap(f, "SetScrollChild", function(self, child)
		local w = self._ft
		if w.scrollChild and w.scrollChild ~= child and w.scrollChild._ft then
			w.scrollChild._ft.scrollFrame = nil
		end
		w.scrollChild = child
		if type(child) == "table" and child._ft then
			child._ft.scrollFrame = self
			adopt(self, child)
		end
	end)
	if not f.GetScrollChild then f.GetScrollChild = function(self) return self._ft.scrollChild end end
	wrap(f, "SetVerticalScroll", function(self, v) self._ft.vscroll = tonumber(v) or 0 end)
	wrap(f, "SetHorizontalScroll", function(self, v) self._ft.hscroll = tonumber(v) or 0 end)
	if not f.GetVerticalScroll then f.GetVerticalScroll = function(self) return self._ft.vscroll or 0 end end
	if not f.GetHorizontalScroll then
		f.GetHorizontalScroll = function(self) return self._ft.hscroll or 0 end
	end
	if not f.GetVerticalScrollRange then
		f.GetVerticalScrollRange = function(self) return FT.scrollRange(self) end
	end
	if not f.UpdateScrollChildRect then f.UpdateScrollChildRect = function(self) return self end end
end

-- Where a frame's edges are, in its own units, for a mock that has no answer.
local function edge(axis, high)
	return function(self)
		local lo, hi = FT.span(self, axis)
		if not lo then return nil end
		return (high and hi or lo) / FT.scaleOf(self)
	end
end
local EDGES = { GetLeft = edge("x", false), GetRight = edge("x", true),
	GetBottom = edge("y", false), GetTop = edge("y", true) }

function W.Frame(f)
	wrap(f, "SetClipsChildren", function(self, v) self._ft.clips = v and true or false end)
	if not f.DoesClipChildren then f.DoesClipChildren = function(self) return self._ft.clips == true end end
	wrap(f, "SetToplevel", function(self, v) self._ft.toplevel = v and true or false end)
	-- Kept as a stamp only: the renderer of the options window draws the frame
	-- raised last on top of its strata; the other renderers draw as before.
	wrap(f, "Raise", function(self) self._ft.raisedAt = stamp() end)
	wrap(f, "EnableKeyboard", function(self, v) self._ft.keyboard = v and true or false end)
	wrap(f, "SetPropagateKeyboardInput", function(self, v) self._ft.propagate = v and true or false end)
	wrap(f, "SetHitRectInsets", function(self, l, r, t, b) self._ft.hitInsets = { l, r, t, b } end)
	if not f.IsMouseOver then f.IsMouseOver = function() return false end end
	for name, fn in pairs(EDGES) do
		if not f[name] then f[name] = fn end
	end
end

local KINDS = { Button = W.Button, EditBox = W.EditBox, Slider = W.Slider, ScrollFrame = W.ScrollFrame }

function FT.extend(f, kind)
	f._ft = f._ft or {}
	if kind == "FontString" then
		W.FontString(f)
	elseif kind ~= "Texture" and kind ~= "MaskTexture" then
		W.Frame(f)
		if KINDS[kind] then KINDS[kind](f) end
	end
end

-- ------------------------------------------------------------------ text and geometry
--
-- A string wraps at the width its anchors or SetWidth give it, so how tall it
-- is depends on where it sits. These answer that from the anchors, by the
-- rules tools/render_options.py draws by: two edges on an axis win over a set
-- size, a set size hangs from one edge or a centre; a scroll child hangs from
-- its scroll frame's top left, moved by the scroll; a thumb sits where its
-- slider's value puts it. Spans are { low, high } in screen units, y up.

-- The renderer's screen; otherwise the size render_prompt.py draws.
FT.screen = nil

local function frac(point, axis)
	point = tostring(point or "CENTER")
	if axis == "x" then
		if point:find("LEFT", 1, true) then return 0 elseif point:find("RIGHT", 1, true) then return 1 end
		return 0.5
	end
	if point:find("BOTTOM", 1, true) then return 0 elseif point:find("TOP", 1, true) then return 1 end
	return 0.5
end

function FT.scaleOf(r)
	local s = 1
	while r do
		s = s * (r._scale or 1)
		r = r._parent
	end
	return s
end

-- Where each of a region's anchors puts it on one axis, by the fraction of
-- its width or height the anchor is at (0, 0.5 or 1). A relative frame given
-- by name, or none, is the parent, as FT.snapshot hands it to the renderer.
local function anchorsOn(r, axis, depth)
	local at, s = {}, FT.scaleOf(r)
	local pts = r.points or {}
	if r._allPointsTo then
		pts = { { "TOPLEFT", r._allPointsTo, "TOPLEFT", 0, 0 },
			{ "BOTTOMRIGHT", r._allPointsTo, "BOTTOMRIGHT", 0, 0 } }
	end
	for _, p in ipairs(pts) do
		local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
		if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
		if type(rel) ~= "table" then rel = r._parent end
		local lo, hi = FT.span(rel, axis, depth)
		if lo then
			local off = (axis == "x" and x or y) or 0
			at[frac(point, axis)] = lo + (hi - lo) * frac(relPoint or point, axis) + off * s
		end
	end
	return at
end

-- The lines a string is drawn in: its own line breaks always, and past those
-- it wraps at its width unless word wrap is off or it has no width.
local function explicitLines(text)
	local out = {}
	text = text:gsub("|n", "\n")
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
	return out
end

local function fallbackWrap(text, width, size)
	local out = {}
	for _, para in ipairs(explicitLines(text)) do
		local line
		for word in para:gmatch("%S+") do
			local trial = line and (line .. " " .. word) or word
			if line and measure(trial, size) > width + 0.5 then
				out[#out + 1] = line
				line = word
			else
				line = trial
			end
		end
		out[#out + 1] = line or ""
	end
	return out
end

-- The width a string wraps at, in its own units: its two edges, else its set
-- width, else none.
function FT.boundWidth(r)
	local at = anchorsOn(r, "x", 0)
	if at[0] and at[1] then return (at[1] - at[0]) / FT.scaleOf(r) end
	return r._width
end

-- The lines drawn, and whether SetMaxLines cut some off. The renderer hands
-- in FT.wrap, which breaks them with the font it draws in.
function FT.textLines(r)
	local text = r._text
	if text == nil or text == "" then return {}, false end
	text = tostring(text)
	local size = r._font and r._font.size or 12
	local width = r._wordWrap ~= false and FT.boundWidth(r) or nil
	local lines
	if not width then
		lines = explicitLines(text)
	elseif FT.wrap then
		lines = explicitLines(FT.wrap(text, width, size, r._ft and r._ft.nonSpaceWrap or false))
	else
		lines = fallbackWrap(text, width, size)
	end
	local cap = r._maxLines
	if type(cap) == "number" and cap > 0 and #lines > cap then
		for i = #lines, cap + 1, -1 do lines[i] = nil end
		return lines, true
	end
	return lines, false
end

-- A line is as tall as the font is big, plus SetSpacing between lines.
function FT.textHeight(r)
	local n = #(FT.textLines(r))
	if n == 0 then return 0 end
	local size = r._font and r._font.size or 12
	return n * size + (n - 1) * (r._ft and r._ft.spacing or 0)
end

-- How tall a box of many lines grows to hold its text: the lines the renderer
-- draws it in, inside its insets. tests/mockwidgets.lua grows the box by
-- this while the recorder is installed.
function FT.editTextHeight(r)
	local text = r._text
	if text == nil or text == "" then return 0 end
	text = tostring(text)
	local ins = r._insets or (r._ft and r._ft.insets) or {}
	local l, rt, t, b = ins[1] or 0, ins[2] or 0, ins[3] or 0, ins[4] or 0
	local size = r._font and r._font.size or 12
	local width = (r._width or 0) - l - rt
	local lines
	if width <= 0 then
		lines = explicitLines(text)
	elseif FT.wrap then
		lines = explicitLines(FT.wrap(text, width, size, false))
	else
		lines = fallbackWrap(text, width, size)
	end
	local n = #lines
	return n * size + (n - 1) * (r._ft and r._ft.spacing or 0) + t + b
end

local function widestLine(r)
	local size, widest = r._font and r._font.size or 12, 0
	for _, line in ipairs(explicitLines(tostring(r._text or ""))) do
		widest = math.max(widest, measure(line, size))
	end
	return widest
end

-- A region's size on one axis in screen units: what it was set to, else, for a
-- string, its text's.
function FT.sizeOn(r, axis)
	local s = FT.scaleOf(r)
	local set
	if axis == "x" then set = r._width else set = r._height end
	if set then return set * s end
	if r._kind == "FontString" then
		if axis == "x" then return widestLine(r) * s end
		return FT.textHeight(r) * s
	end
	return 0
end

local function scrollChildSpan(r, sf, axis, depth)
	local lo, hi = FT.span(sf, axis, depth)
	if not lo then return nil end
	local s = FT.scaleOf(r)
	if axis == "x" then
		local left = lo - (sf._ft.hscroll or 0) * s
		return left, left + (r._width and r._width * s or (hi - lo))
	end
	local top = hi + (sf._ft.vscroll or 0) * s
	return top - (r._height or 0) * s, top
end

local function thumbSpan(r, slider, axis, depth)
	local lo, hi = FT.span(slider, axis, depth)
	if not lo then return nil end
	local s, w = FT.scaleOf(r), slider._ft
	local vertical = w.orientation == "VERTICAL"
	local along = (axis == "y") == vertical
	local size
	if axis == "x" then size = r._width else size = r._height end
	size = size and size * s or (along and 16 * s or (hi - lo))
	if not along then
		local mid = (lo + hi) / 2
		return mid - size / 2, mid + size / 2
	end
	local min, max = w.min or 0, w.max or 1
	local t = max > min and ((w.value or min) - min) / (max - min) or 0
	t = math.max(0, math.min(1, t))
	-- A vertical slider has its minimum at the top.
	if vertical then t = 1 - t end
	local start = lo + t * (hi - lo - size)
	return start, start + size
end

function FT.span(r, axis, depth)
	depth = (depth or 0) + 1
	if type(r) ~= "table" or depth > 64 then return nil end
	if r == UIParent then
		local screen = FT.screen or {}
		if axis == "x" then return 0, screen.width or 1600 end
		return 0, screen.height or Mock.screenHeight or 1000
	end
	local w = r._ft
	if w and w.scrollFrame then return scrollChildSpan(r, w.scrollFrame, axis, depth) end
	if w and w.thumbOf then return thumbSpan(r, w.thumbOf, axis, depth) end
	local at = anchorsOn(r, axis, depth)
	if at[0] and at[1] then return at[0], at[1] end
	local size = FT.sizeOn(r, axis)
	if at[0] then return at[0], at[0] + size end
	if at[1] then return at[1] - size, at[1] end
	if at[0.5] then return at[0.5] - size / 2, at[0.5] + size / 2 end
	return nil
end

-- How far a scroll frame can scroll: its child's height past its own.
function FT.scrollRange(sf)
	local child = sf._ft and sf._ft.scrollChild
	if not child then return 0 end
	local clo, chi = FT.span(child, "y")
	local lo, hi = FT.span(sf, "y")
	if not clo or not lo then return 0 end
	return math.max(0, ((chi - clo) - (hi - lo)) / FT.scaleOf(sf))
end

instrument = function(f, kind, parent, layer, sublevel)
	FT.serial = FT.serial + 1
	f._serial = FT.serial
	f._kind = kind
	f._parent = parent
	f._layer = layer
	f._sublevel = sublevel or 0
	f._children = {}
	if parent and parent._children then parent._children[#parent._children + 1] = f end
	FT.all[#FT.all + 1] = f

	-- Every frame in the client is one level above its parent unless told
	-- otherwise, and that is what decides which frame draws over which.
	if kind ~= "Texture" and kind ~= "FontString" and kind ~= "MaskTexture" then
		f._level = parent and parent._level and (parent._level + 1) or 0
	end
	f.SetFrameLevel = function(self, level) self._level = level return self end
	f.GetFrameLevel = function(self) return self._level or 0 end
	wrap(f, "SetFrameStrata", function(self, strata) self._strata = strata end)
	f.GetFrameStrata = function(self) return self._strata or (self._parent and self._parent.GetFrameStrata
		and self._parent:GetFrameStrata()) or "MEDIUM" end
	f.GetParent = function(self) return self._parent end
	-- Moved under another frame, which is what it then draws with: a look
	-- from Looks/ puts the reason line inside its tag.
	wrap(f, "SetParent", function(self, parent)
		local old = self._parent
		if old and old._children then
			for i, child in ipairs(old._children) do
				if child == self then table.remove(old._children, i) break end
			end
		end
		self._parent = parent
		if parent and parent._children then parent._children[#parent._children + 1] = self end
		-- A frame moved under another sits one level above it, as the client
		-- puts it (SetFixedFrameLevel is the client's way to stop that).
		if parent and parent._level and self._level then FT.relevel(self, parent._level + 1) end
	end)
	f.IsVisible = function(self) return FT.visible(self) end

	-- Texture state. SetVertexColor after a gradient replaces it, as it does in
	-- the client, so each is stamped and the later one wins.
	f.SetTexture = function(self, file)
		self._file, self._colorTexture, self._atlas = file, nil, nil
		return self
	end
	f.GetTexture = function(self) return self._file end
	f.SetColorTexture = function(self, r, g, b, a)
		self._colorTexture, self._file, self._atlas = { r, g, b, a == nil and 1 or a }, nil, nil
		return self
	end
	f.SetAtlas = function(self, atlas) self._atlas = atlas return self end
	f.SetTexCoord = function(self, ...) self._texCoord = { ... } return self end
	f.SetBlendMode = function(self, mode) self._blend = mode return self end
	f.SetDesaturated = function(self, on) self._desaturated = on and true or false return self end
	f.SetRotation = function(self, radians) self._rotation = radians return self end
	f.SetDrawLayer = function(self, layer, sub) self._layer, self._sublevel = layer, sub or 0 return self end
	wrap(f, "SetVertexColor", function(self) self._gradient = nil end)
	f.SetGradient = function(self, orientation, c1, c2)
		self._gradient = { orientation, c1, c2 }
		return self
	end
	f.AddMaskTexture = function(self, mask) self._mask = mask return self end
	f.RemoveMaskTexture = function(self) self._mask = nil return self end

	-- Font string state.
	f.SetJustifyH = function(self, v) self._justifyH = v return self end
	f.SetJustifyV = function(self, v) self._justifyV = v return self end
	f.SetShadowColor = function(self, r, g, b, a) self._shadowColor = { r, g, b, a } return self end
	f.SetShadowOffset = function(self, x, y) self._shadowOffset = { x, y } return self end
	f.SetWordWrap = function(self, v) self._wordWrap = v return self end
	-- How wide the text is, on one line (see measure above).
	f.GetStringWidth = function(self)
		return measure(self._text, self._font and self._font.size or 12)
	end
	-- The client's other measure, the one that ignores the width the anchors
	-- put on the string. Nothing here wraps or cuts, so the two are the same.
	f.GetUnboundedStringWidth = f.GetStringWidth

	-- Points kept whole, and SetAllPoints turned into the two points it is, so
	-- the renderer has one shape to lay out. Through the mock's own wrappers,
	-- so a call made on the secure button in combat is still written down.
	wrap(f, "SetAllPoints", function(self, rel)
		local to = (type(rel) == "table" and rel) or self._parent
		self._allPointsTo = to
	end)
	local clear = f.ClearAllPoints
	f.ClearAllPoints = function(self, ...)
		self._allPointsTo = nil
		return clear(self, ...)
	end
	local setPoint = f.SetPoint
	f.SetPoint = function(self, ...)
		self._allPointsTo = nil
		return setPoint(self, ...)
	end

	f.CreateTexture = function(self, _, layer, _, sub)
		local t = base()
		instrument(t, "Texture", self, layer or "ARTWORK", sub)
		return t
	end
	f.CreateFontString = function(self, _, layer)
		local t = base()
		instrument(t, "FontString", self, layer or "ARTWORK", 0)
		return t
	end
	f.CreateMaskTexture = function(self, _, layer)
		local t = base()
		instrument(t, "MaskTexture", self, layer or "ARTWORK", 0)
		return t
	end
	f.CreateAnimationGroup = function(self) return newGroup(self) end

	-- The highlight a Button draws under the mouse. A child texture like any
	-- other, in the HIGHLIGHT layer, which the renderer leaves out unless asked:
	-- nothing is hovering in a still picture.
	f.SetHighlightTexture = function(self, file, blend)
		local t = self._highlight
		if not t then
			t = base()
			instrument(t, "Texture", self, "HIGHLIGHT", 0)
			t._allPointsTo = self
			self._highlight = t
		end
		t._file = file
		t._blend = blend
		return self
	end
	f.GetHighlightTexture = function(self) return self._highlight end

	-- Cooldown frames: the sweep is drawn from a start and a duration, so those
	-- are what is kept.
	if kind == "Cooldown" then
		f.SetCooldown = function(self, start, duration, modRate)
			self._cooldown = { start = start, duration = duration, modRate = modRate }
			return self
		end
		f.Clear = function(self) self._cooldown = nil return self end
		f.GetCooldownTimes = function(self)
			local c = self._cooldown
			if not c then return 0, 0 end
			return c.start * 1000, c.duration * 1000
		end
		f.SetSwipeColor = function(self, r, g, b, a) self._swipeColor = { r, g, b, a } return self end
		f.SetSwipeTexture = function(self, file) self._swipeTexture = file return self end
		f.SetDrawEdge = function(self, v) self._drawEdge = v return self end
		f.SetDrawSwipe = function(self, v) self._drawSwipe = v return self end
		f.SetDrawBling = function(self, v) self._drawBling = v return self end
		f.SetHideCountdownNumbers = function(self, v) self._hideNumbers = v return self end
		f.SetReverse = function(self, v) self._reverse = v return self end
		f.SetUseCircularEdge = function(self, v) self._circular = v return self end
		f.SetEdgeScale = function(self, v) self._edgeScale = v return self end
	end
	FT.extend(f, kind)
	return f
end
FT.instrument = instrument

local realCreateFrame
-- The mock's own measure for a box of many lines, put back on uninstall.
local mockEditHeight

-- Swap the recording CreateFrame in. UIParent is adopted as the root, sized to
-- the screen the mock describes.
function FT.install()
	if realCreateFrame then return end
	base = Mock.newFrame
	realCreateFrame = CreateFrame
	mockEditHeight = Mock.editTextHeight
	if mockEditHeight then Mock.editTextHeight = FT.editTextHeight end
	FT.all, FT.log, FT.serial = {}, {}, 0
	FT.stamps, FT.focus = 0, nil
	-- Adopted afresh on every install, not once: the serials start again at
	-- zero, and a root still carrying the last install's number would share it
	-- with the first frame made after this one.
	if not UIParent._children then
		instrument(UIParent, "Frame", nil, nil)
	else
		FT.serial = FT.serial + 1
		UIParent._serial = FT.serial
		FT.all[1] = UIParent
	end
	UIParent._level = 0
	UIParent._children = {}
	UIParent._ft = UIParent._ft or {}
	CreateFrame = function(kind, name, parent, template)
		local f = base()
		instrument(f, kind or "Frame", parent or UIParent, nil)
		f._name = name
		f._template = template
		FT.template(f, template)
		if name then _G[name] = f end
		return f
	end
end

-- What a template gives a frame before the addon touches it. The window's
-- close X is the only template it uses: 24 square, and a click hides the
-- frame it sits on.
function FT.template(f, template)
	if type(template) ~= "string" or not template:find("UIPanelCloseButton", 1, true) then return end
	f._width, f._height = f._width or 24, f._height or 24
	if not f.scripts.OnClick then
		f.scripts.OnClick = function(self)
			local parent = self._parent
			if parent and parent.Hide then parent:Hide() end
		end
	end
end

function FT.uninstall()
	if not realCreateFrame then return end
	CreateFrame = realCreateFrame
	realCreateFrame = nil
	if mockEditHeight then Mock.editTextHeight = mockEditHeight end
	mockEditHeight = nil
end

-- A plain copy of the tree, one entry per region, with every reference to
-- another region replaced by its serial number. What the renderer reads.
function FT.snapshot(root)
	local out = {}
	local function ref(r) return type(r) == "table" and r._serial or nil end
	local function copyPoints(r)
		local pts = {}
		if r._allPointsTo then
			pts[1] = { "TOPLEFT", ref(r._allPointsTo), "TOPLEFT", 0, 0 }
			pts[2] = { "BOTTOMRIGHT", ref(r._allPointsTo), "BOTTOMRIGHT", 0, 0 }
			return pts
		end
		for i, p in ipairs(r.points or {}) do
			-- The client's four shapes: (point), (point, x, y), (point, rel,
			-- relPoint), (point, rel, relPoint, x, y).
			local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
			if type(a) == "number" then
				pts[i] = { point, ref(r._parent), point, a, b or 0 }
			elseif a == nil then
				-- (point) alone, or (point, nil, relPoint, x, y): nil is the parent.
				pts[i] = { point, ref(r._parent), b or point, c or 0, d or 0 }
			else
				pts[i] = { point, ref(a), b or point, c or 0, d or 0 }
			end
		end
		return pts
	end
	local function anims(r)
		local list = {}
		for _, g in ipairs(r._groups or {}) do
			local a = {}
			for i, anim in ipairs(g._anims) do
				a[i] = { kind = anim._kind, order = anim._order, duration = anim._duration,
					delay = anim._startDelay, fromAlpha = anim._fromAlpha, toAlpha = anim._toAlpha,
					offset = anim._offset, smoothing = anim._smoothing,
					scaleFrom = anim._scaleFrom, scaleTo = anim._scaleTo, origin = anim._origin,
					target = ref(anim._target) }
			end
			list[#list + 1] = { playing = g._playing, startedAt = g._startedAt,
				looping = g._looping, anims = a, serial = g._serial }
		end
		return list
	end
	local wanted = {}
	local function walk(r)
		wanted[r] = true
		for _, c in ipairs(r._children or {}) do walk(c) end
	end
	walk(root or UIParent)
	for _, r in ipairs(FT.all) do
		if wanted[r] then
			out[#out + 1] = FT.widgetFields(r, ref, {
				id = r._serial, kind = r._kind, parent = ref(r._parent), name = r._name,
				layer = r._layer, sublevel = r._sublevel, level = r._level,
				strata = r._strata,
				shown = r._shown ~= false, alpha = r._alpha, scale = r._scale,
				width = r._width, height = r._height, points = copyPoints(r),
				file = r._file, colorTexture = r._colorTexture, atlas = r._atlas,
				color = r._color, gradient = r._gradient and {
					r._gradient[1], r._gradient[2], r._gradient[3] } or nil,
				texCoord = r._texCoord, blend = r._blend, mask = ref(r._mask),
				desaturated = r._desaturated,
				text = r._text, font = r._font, textColor = r._textColor,
				justifyH = r._justifyH, justifyV = r._justifyV,
				-- Whether the client would cut a long line with an ellipsis
				-- rather than let it run on: without it, the renderer drew
				-- every overlong line straight off the edge of the panel.
				wordWrap = r._wordWrap,
				shadowColor = r._shadowColor, shadowOffset = r._shadowOffset,
				cooldown = r._cooldown, swipeColor = r._swipeColor, reverse = r._reverse,
				swipeTexture = r._swipeTexture,
				drawEdge = r._drawEdge,
				groups = anims(r),
			})
		end
	end
	return out
end

-- What the widgets above recorded, added to a snapshot entry. References to
-- other regions go through `ref`, as everything in the snapshot does.
function FT.widgetFields(r, ref, entry)
	local w = r._ft or {}
	entry.template = r._template
	entry.maxLines = r._maxLines
	entry.fontObject, entry.objColor = w.fontObject, w.objColor
	-- Whether the font object's colour came after SetTextColor's.
	entry.objLater = (w.objAt or 0) > (w.colorAt or 0)
	entry.spacing, entry.nonSpaceWrap = w.spacing, w.nonSpaceWrap
	entry.clips, entry.enabled, entry.raisedAt = w.clips, w.enabled, w.raisedAt
	entry.scrollChild, entry.scrollFrame = ref(w.scrollChild), ref(w.scrollFrame)
	entry.vscroll, entry.hscroll = w.vscroll, w.hscroll
	entry.multiLine, entry.insets, entry.focus = w.multiLine, w.insets, w.focus
	entry.orientation, entry.value = w.orientation, w.value
	entry.minValue, entry.maxValue = w.min, w.max
	entry.thumb, entry.thumbOf = ref(w.thumb), ref(w.thumbOf)
	return entry
end

return FT
