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
-- Used two ways. tools/render_prompt.py walks the tree and draws it, and
-- tests/scenarios/look.lua asks which animations are playing, which is the only
-- evidence that an effect starts and stops: against the mock's own groups,
-- whose IsPlaying always answers false, a pulse that never stops and one that
-- never starts are the same pulse.
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
	g.GetAnimations = function(self) return table.unpack(self._anims) end
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
	f.GetStringWidth = function(self)
		local text = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		local size = self._font and self._font.size or 12
		return #text * size * 0.5
	end

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
	return f
end
FT.instrument = instrument

local realCreateFrame

-- Swap the recording CreateFrame in. UIParent is adopted as the root, sized to
-- the screen the mock describes.
function FT.install()
	if realCreateFrame then return end
	base = Mock.newFrame
	realCreateFrame = CreateFrame
	FT.all, FT.log, FT.serial = {}, {}, 0
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
	CreateFrame = function(kind, name, parent, template)
		local f = base()
		instrument(f, kind or "Frame", parent or UIParent, nil)
		f._name = name
		f._template = template
		if name then _G[name] = f end
		return f
	end
end

function FT.uninstall()
	if not realCreateFrame then return end
	CreateFrame = realCreateFrame
	realCreateFrame = nil
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
				pts[i] = { point, ref(r._parent), point, 0, 0 }
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
			out[#out + 1] = {
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
				shadowColor = r._shadowColor, shadowOffset = r._shadowOffset,
				cooldown = r._cooldown, swipeColor = r._swipeColor, reverse = r._reverse,
				swipeTexture = r._swipeTexture,
				drawEdge = r._drawEdge,
				groups = anims(r),
			}
		end
	end
	return out
end

return FT
