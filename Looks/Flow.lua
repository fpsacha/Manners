-- Manners -- Flow: art that moves under its own clock, for the looks.
--
-- An animation group can fade, slide, grow and turn a region. It cannot make a
-- texture flow -- lava creeping along a seam, a nebula drifting inside a
-- crystal, fel fire licking up a rune -- and it cannot play a drawn animation
-- frame by frame at a film's speed. Both are a matter of moving a texture's
-- coordinates a little at a time, which is what this file does and nothing
-- else: a look hands it a texture and says how it flows, and Flow writes the
-- coordinates.
--
--   local flow = ns.Looks.Flow.New(kit.art)      once, in Build
--   local lava = flow:Scroll(tex, du, dv, uSpan, vSpan, turn)
--       tex was made with the wrap mode "REPEAT"; it shows a window uSpan by
--       vSpan of the file (1 is the whole file; more tiles it) that moves du,
--       dv files a second. lava:Window(uSpan, vSpan) resizes the window (in
--       Apply, when the region's size changes), lava:Speed(du, dv) the speed,
--       lava:Phase(u, v) where the window stands. `turn` lays the file's
--       length another way on the screen, in quarter turns: 0 left to right,
--       1 top to bottom, 2 right to left, 3 bottom to top -- one strip of
--       light run round the four sides of a box.
--   local fire = flow:Sheet(tex, cols, rows, frames, fps, loop)
--       tex shows a sheet of drawn frames, cols by rows, `frames` of them, at
--       fps frames a second: over and over (`loop`), or once, after which
--       fire.done(fire) is called if it is set. A sheet's frames are read left
--       to right, top to bottom.
--   h:Play()  h:Stop()  h:IsPlaying()
--       Play starts a handle from its beginning (a scroll from where it
--       stands); Stop leaves the texture as it stands. A handle that is not
--       playing costs nothing.
--   flow:StopAll()                                in Hide
--   flow:Tick(now)                                what the clock calls
--
-- The clock is one OnUpdate on a frame of the look's own art, held to thirty
-- writes a second and running only while some handle plays, so a look at rest
-- with nothing flowing runs no script at all; and a frame that is not shown
-- gets no OnUpdate, so the prompt hidden stops it with nothing said. Every
-- coordinate is worked out from the clock's own time, never added up, so a
-- pause and a low frame rate change nothing but smoothness. It touches no
-- secure frame and no protected function: SetTexCoord on a look's own texture
-- is as free in a fight as SetAlpha.
--
-- The looks used to keep to "no OnUpdate" (Looks/Looks.lua, tests/scenarios/
-- look.lua). The author lifted that for art: this driver is the one OnUpdate a
-- look may run, and it is marked (`mannersFlow`) so the scenarios that look
-- for a stray one can tell it apart.

local _, ns = ...

local Flow = {}
ns.Looks.Flow = Flow

-- Seconds between writes: thirty a second is a film's worth for a drawn
-- flame, and a scroll that slow in the eye is smooth at it.
local STEP = 1 / 30

local Handle = {}
Handle.__index = Handle

function Handle:Play()
	local flow = self.flow
	self.t0 = GetTime()
	if not self.playing then
		self.playing = true
		flow.live = flow.live + 1
		flow.driver:Show()
	end
	self:Write(self.t0)
	return self
end

function Handle:Stop()
	if self.playing then
		self.playing = false
		-- A scroll rests where it stands, and goes on from there.
		if self.kind == "scroll" then self:Speed(self.du, self.dv) end
		local flow = self.flow
		flow.live = flow.live - 1
		if flow.live <= 0 then
			flow.live = 0
			flow.driver:Hide()
		end
	end
	return self
end

function Handle:IsPlaying()
	return self.playing == true
end

-- A scroll's window, in files.
function Handle:Window(uSpan, vSpan)
	self.uSpan, self.vSpan = uSpan, vSpan
	if self.kind == "scroll" then self:Write(GetTime()) end
	return self
end

function Handle:Speed(du, dv)
	-- Kept where it stands: the offset so far is folded into the base.
	local now = GetTime()
	local t = now - (self.t0 or now)
	self.u0 = ((self.u0 or 0) + (self.du or 0) * t) % 1
	self.v0 = ((self.v0 or 0) + (self.dv or 0) * t) % 1
	self.t0 = now
	self.du, self.dv = du, dv
	return self
end

-- Where a scroll's window stands, in files.
function Handle:Phase(u, v)
	self.u0, self.v0 = (u or 0) % 1, (v or 0) % 1
	self.t0 = GetTime()
	if self.kind == "scroll" then self:Write(self.t0) end
	return self
end

-- The window's four corners for a quarter turn, as SetTexCoord takes them:
-- upper left, lower left, upper right, lower right.
local function Turned(tex, turn, u0, u1, v0, v1)
	if turn == 1 then
		tex:SetTexCoord(u0, v1, u1, v1, u0, v0, u1, v0)
	elseif turn == 2 then
		tex:SetTexCoord(u1, v1, u1, v0, u0, v1, u0, v0)
	else
		tex:SetTexCoord(u1, v0, u0, v0, u1, v1, u0, v1)
	end
end

-- The coordinates for the moment `now`.
function Handle:Write(now)
	local t = now - (self.t0 or now)
	if self.kind == "scroll" then
		local u = ((self.u0 or 0) + self.du * t) % 1
		local v = ((self.v0 or 0) + self.dv * t) % 1
		if self.turn then
			Turned(self.tex, self.turn, u, u + self.uSpan, v, v + self.vSpan)
		else
			self.tex:SetTexCoord(u, u + self.uSpan, v, v + self.vSpan)
		end
		return
	end
	local frame = math.floor(t * self.fps)
	if frame >= self.frames then
		if self.loop then
			frame = frame % self.frames
		else
			-- A sheet played once rests on its last frame; the look fades it.
			frame = self.frames - 1
			if self.playing then
				self:Stop()
				if self.done then self.done(self) end
			end
		end
	end
	if frame ~= self.shown then
		self.shown = frame
		local col, row = frame % self.cols, math.floor(frame / self.cols)
		self.tex:SetTexCoord(col / self.cols, (col + 1) / self.cols, row / self.rows, (row + 1) / self.rows)
	end
end

local Methods = {}
Methods.__index = Methods

function Methods:Scroll(tex, du, dv, uSpan, vSpan, turn)
	turn = turn and turn % 4 or 0
	local h = setmetatable({ flow = self, kind = "scroll", tex = tex, du = du or 0, dv = dv or 0,
		uSpan = uSpan or 1, vSpan = vSpan or 1, u0 = 0, v0 = 0, turn = turn ~= 0 and turn or nil }, Handle)
	self.handles[#self.handles + 1] = h
	h:Write(GetTime())
	return h
end

function Methods:Sheet(tex, cols, rows, frames, fps, loop)
	local h = setmetatable({ flow = self, kind = "sheet", tex = tex, cols = cols, rows = rows,
		frames = frames or cols * rows, fps = fps or 24, loop = loop and true or false }, Handle)
	self.handles[#self.handles + 1] = h
	tex:SetTexCoord(0, 1 / cols, 0, 1 / rows)
	h.shown = 0
	return h
end

function Methods:StopAll()
	for _, h in ipairs(self.handles) do h:Stop() end
end

function Methods:Tick(now)
	for _, h in ipairs(self.handles) do
		if h.playing then h:Write(now) end
	end
end

-- A flow for one look, its clock a frame of `parent` (the look's art): hidden
-- with it, and hidden while nothing plays.
function Flow.New(parent)
	local flow = setmetatable({ handles = {}, live = 0 }, Methods)
	local driver = CreateFrame("Frame", nil, parent)
	driver.mannersFlow = true
	driver:Hide()
	local since = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		since = since + (elapsed or 0)
		if since < STEP then return end
		since = 0
		flow:Tick(GetTime())
	end)
	flow.driver = driver
	Flow.all[#Flow.all + 1] = flow
	return flow
end

-- Every flow made, for whatever draws the prompt without a game's clock (the
-- renderer, a scenario): Flow.TickAll(now) writes each as it stands at `now`.
Flow.all = {}
function Flow.TickAll(now)
	for _, flow in ipairs(Flow.all) do flow:Tick(now or GetTime()) end
end
