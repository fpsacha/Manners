-- Manners -- Minimal, dressed: a few lines of light under the words.
--
-- THE SOURCE. The game's own spare interface: the nameplate and the cast bar.
-- A name with one thin bar under it; the bar fills behind a spark as a spell
-- is cast, flashes as it lands and goes red when it is interrupted; and a
-- ready check answers with a tick or a cross. Minimal stays what it is, words
-- on the world with no panel, and is given that much finish and no more:
--
--   * a hairline under the words, from where they start to where they may
--     end, a small tick turned up at each end: the prompt's edge, lit in the
--     reason's colour on a dark bed, so it reads over snow as over a cave;
--   * at rest, a glint that crosses the line now and then;
--   * somebody owed: the line is CAST, filling from the left behind the cast
--     bar's spark, the far tick catching the spark as it arrives; then it
--     stands at full, breathing, and the spark runs it again and again;
--   * a buff landed: the spark dashes the line, the whole line flashes hot,
--     and the ready check's tick is struck onto the icon's corner;
--   * a buff refused: the line goes red, sputters and runs back out the way
--     it was cast, as an interrupted cast does; the ready check's cross is
--     struck onto the icon's corner; and the line comes back in the
--     reason's colour.
--
-- It is a DRESSING (Looks/Looks.lua), not a look: Prompt/Panel.lua still draws
-- Minimal's icon, its bezel, its text and every light it drew before, and
-- tests them; this file adds to that and takes away only what it added.
-- `prompt.minimalLine = false` takes all of it off again (the Minimal of
-- before); nothing sets it yet, so it is on.
--
-- Nothing here is scaled, so nothing can grow over the words: the fill and
-- the sparks slide inside a frame that cuts them at the left tick (nothing
-- lit is ever seen left of where the line starts), and every light is an
-- alpha. The two marks are drawn animations, played frame by frame by
-- Looks/Flow.lua. On Calm nothing moves and nothing loops: the line stands,
-- lit. In a fight the loops stop and the line rests.
--
-- `idle` lists the animation groups that loop with nobody owed (the glint at
-- rest): the author asked for a prompt that is alive at rest, and the
-- scenarios that hold every other look to "nothing loops while it is idle"
-- pass these by name.
--
-- The art is Textures/Minimal, drawn by tools/make_minimal_textures.py.

local _, ns = ...
local Colour = ns.Looks.Colour
local Looks = ns.Looks

local ART = "Interface\\AddOns\\Manners\\Textures\\Minimal\\Minimal_"

-- ---- must agree with tools/make_minimal_textures.py --------------------
-- How far the hairline's middle is over the foot of its file and of the
-- cap's (the two files are one height, and every piece of a line is laid at
-- that height: the client rounds a texture's edges to the screen, and pieces
-- of two heights would be rounded apart, a step in the hairline where they
-- meet), the cap's file in units, where the tick's middle is in from the
-- cap's outer edge, half the hairline's thickness, the spark's file and where
-- its head is along it, the glow's height, and the marks' sheets.
local LINE_MID, CAP_W, CAP_H, TICK_X, CORE = 4, 8, 16, 2.4, 0.7
local SPARK_W, SPARK_H, SPARK_HEAD, GLOW_H = 32, 16, 0.75, 16
local MARK_COLS, MARK_ROWS, MARK_FRAMES = 4, 2, 8

-- ---- must agree with Prompt/Effects.lua --------------------------------
-- The red-amber a refusal breaks in: the halo's, the crack's, and this line's.
local BREAK = { 1.00, 0.42, 0.20 }

-- The line: how far its light's middle is above the panel's foot (where
-- Panel.lua's bottom rule lies, so a landing's flare falls on it) and how far
-- short of the panel's right edge it stops. Everything is drawn for a panel
-- 44 tall and follows the height between these two.
local LINE_UP, LINE_END = 2.5, 8
-- The cut the fill and the sparks slide in. On the left it stands CUT_KEEP
-- outside the left tick's outer edge and no further: the fill is cast from
-- that side and runs back out to it, and a spark's tail trails that way, and
-- none of them may be seen left of where the line starts. On the right it
-- stands FLARE past the line's box: nothing goes there but a spark's own
-- flare as it reaches the far tick, which a nearer cut would shear (and
-- which stays inside the panel: FLARE and the cap's margin are under
-- LINE_END at the largest scale).
local CUT_KEEP, FLARE = 0.25, 4.5
-- Where the two sparks that fade in standing still (the run while somebody
-- is owed, the glint at rest) start: this far inside the left tick, so the
-- cut is well behind the head's halo and only crosses its tail, which lies
-- on the line.
local START_IN = 3
local SCALE_AT, SCALE_LO, SCALE_HI = 44, 0.55, 1.2
-- The unlit line under the fill: a cool grey, faint.
local TRACK = { 0.62, 0.64, 0.72 }
local TRACK_ALPHA = 0.5
-- The fill: at rest, and while somebody is owed; how far its colour is taken
-- towards white; the low of its breath and the breath's length.
local REST, OWED, FILL_LIFT = 0.62, 1, 0.22
local BREATH_LO, BREATH = 0.70, 1.1
-- The glow under the lit line while somebody is owed (none at rest).
local GLOW = 0.6
-- With the reason's marker off, plain warm light.
local WARM = { 1.00, 0.93, 0.78 }
-- The cast: how long the line takes to fill, the beat before it starts, and
-- how much of that beat the fill takes to get out of sight (hidden all the
-- while).
local CAST, CAST_LEAD, CAST_AWAY = 0.50, 0.04, 0.02
-- The far tick catching the spark: its peak and its two halves.
local PING, PING_UP, PING_DOWN = 0.8, 0.05, 0.30
-- The spark running the line while somebody is owed: held, in, across, held.
-- 2.45 s a turn.
local PATROL = { hold = 0.6, up = 0.15, run = 1.1, down = 0.3, rest = 0.6, peak = 0.95 }
-- The glint at rest: the same, slower and fainter. 4.8 s a turn.
local DRIFT = { hold = 0.8, up = 0.3, run = 1.9, down = 0.5, rest = 1.8, peak = 0.5 }
-- A landing: the dash along the line, and the line's own flash (additive,
-- under 0.6 s as every additive light here).
local DASH, DASH_DOWN = 0.20, 0.10
local HOT, HOT_UP, HOT_DOWN = 0.85, 0.06, 0.44
-- A refusal: the red line's sputter (down, up, held), its run back out to
-- the left (fading to SPUTTER_END as it goes), and its way back in.
local SPUTTER = { 0.05, 0.05, 0.06, 0.22 }
local SPUTTER_LOW, SPUTTER_END, BACK = 0.25, 0.55, 0.25
-- The mark on the icon's corner: its size against the icon and the least it
-- is drawn at, where its middle is in from the icon's corner (a share of the
-- icon), its frames a second, and how long it comes, stays and goes.
local MARK_SIZE, MARK_LEAST, MARK_IN, MARK_FPS = 0.72, 12, 0.20, 40
local STAMP_UP, STAMP_HOLD, STAMP_DOWN = 0.03, 0.42, 0.25
-- The marks' colours: the outcome's own words' (Prompt/Paint.lua).
local TICK_COLOUR, CROSS_COLOUR = { 0.66, 0.97, 0.66 }, { 1.00, 0.52, 0.44 }

local Minimal = { idle = {} }
Looks.RegisterDress("minimal", Minimal)

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, duration, order, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(0, 0)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- A group leaves its frame at `to` (a number, or a function that says)
-- however it ends.
local function Park(group, frame, to)
	local function park() frame:SetAlpha(type(to) == "function" and to() or to or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Replay(g)
	g:Stop()
	g:Play()
end

local function Stop(g)
	if g:IsPlaying() then g:Stop() end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Minimal:Build(kit)
	self.kit = kit
	local art = kit.art
	local own = {}
	self.own = own
	local function tex(parent, file, blend, sublevel)
		local t = parent:CreateTexture(nil, "ARTWORK", nil, sublevel or 1)
		t:SetTexture(ART .. file)
		t:SetBlendMode(blend or "BLEND")
		own[#own + 1] = t
		return t
	end
	local base = art:GetFrameLevel()
	local function frame(parent, level)
		local f = CreateFrame("Frame", nil, parent)
		f:SetFrameLevel(base + level)
		return f
	end
	-- A line from end to end: the left cap, the hairline, the right cap (the
	-- left one's file drawn the other way round).
	local function bar(parent, blend)
		local b = { tex(parent, "Cap", blend), tex(parent, "Line", blend), tex(parent, "Cap", blend) }
		b[3]:SetTexCoord(1, 0, 0, 1)
		return b
	end
	local function spark(parent)
		local f = frame(parent, 3)
		f:SetAlpha(0)
		f.tex = tex(f, "Spark", "BLEND", 2)
		f.tex:SetAllPoints(f)
		return f
	end

	-- Everything stands on one frame over art, under the text: the unlit line
	-- on the frame itself, the fill and the sparks inside a frame that cuts
	-- them at the left tick (Apply, the cut).
	local root = frame(art, 1)
	root:SetAllPoints(art)
	self.frame = root
	local box = frame(root, 1)
	self.box = box
	self.track = bar(box)
	local clip = frame(root, 2)
	if clip.SetClipsChildren then clip:SetClipsChildren(true) end
	self.clip = clip
	local fill = frame(clip, 3)
	fill:SetAllPoints(box)
	fill:SetAlpha(REST)
	self.fill = fill
	self.fillBar = bar(fill)
	-- The lit line's glow, under the hairline: the fill's own, so it is cast,
	-- breathes and sputters with it. At nothing until somebody is owed.
	self.glow = tex(fill, "Glow", "BLEND", 0)
	-- Three sparks, one for each thing a spark does, so no two groups ever
	-- move one frame: the cast and the landing's dash, the run while somebody
	-- is owed, the glint at rest.
	self.spark, self.rover, self.glint = spark(clip), spark(clip), spark(clip)
	-- The line's own flash and the far tick's, additive, parked at nothing.
	local hot = frame(root, 3)
	hot:SetAllPoints(box)
	hot:SetAlpha(0)
	self.hot = hot
	self.hotBar = bar(hot, "ADD")
	local ping = frame(root, 3)
	ping:SetAlpha(0)
	self.ping = ping
	self.pingCap = tex(ping, "Cap", "ADD")
	self.pingCap:SetTexCoord(1, 0, 0, 1)
	self.pingCap:SetAllPoints(ping)
	-- The mark on the icon's corner: the tick and the cross on one frame, one
	-- of them shown.
	local badge = frame(root, 3)
	badge:SetAlpha(0)
	self.badge = badge
	self.check, self.cross = tex(badge, "Check"), tex(badge, "Cross")
	self.check:SetAllPoints(badge)
	self.cross:SetAllPoints(badge)
	self.cross:Hide()

	-- What is drawn frame by frame.
	local flow = Looks.Flow.New(root)
	self.flow = flow
	self.checkSheet = flow:Sheet(self.check, MARK_COLS, MARK_ROWS, MARK_FRAMES, MARK_FPS, false)
	self.crossSheet = flow:Sheet(self.cross, MARK_COLS, MARK_ROWS, MARK_FRAMES, MARK_FPS, false)

	-- What moves by animation. The slides' lengths are the line's, written in
	-- Apply.
	local anims = {}
	self.anims = anims
	local function group(region, looping)
		local g = region:CreateAnimationGroup()
		if looping then g:SetLooping(looping) end
		anims[#anims + 1] = g
		return g
	end
	local function level() return self.owed and OWED or REST end

	-- The cast: the fill starts a line's length to the left, out of sight,
	-- and slides in; the spark rides its leading end. A slide ends where it
	-- began, so the first step takes the fill away (hidden for that beat) and
	-- the second brings it home, where it stays.
	local fillIn = group(fill)
	Alpha(fillIn, 0, 0, CAST_LEAD, 1)
	fillIn.away = Slide(fillIn, CAST_AWAY, 1)
	Alpha(fillIn, 0, 1, 0.05, 2, nil, "OUT")
	fillIn.home = Slide(fillIn, CAST, 2, "OUT")
	Park(fillIn, fill, level)
	self.fillIn = fillIn
	local cast = group(self.spark)
	Alpha(cast, 0, 1, CAST_LEAD, 1)
	cast.away = Slide(cast, CAST_AWAY, 1)
	cast.run = Slide(cast, CAST, 2, "OUT")
	Alpha(cast, 1, 0, 0.16, 2, CAST - 0.16, "IN")
	-- The far tick catches the spark as it arrives (never when the cast was
	-- cut short: OnStop only parks).
	cast:SetScript("OnFinished", function()
		self.spark:SetAlpha(0)
		if self.active and self.kit.FullEffects() then Replay(self.pinged) end
	end)
	cast:SetScript("OnStop", function() self.spark:SetAlpha(0) end)
	self.cast = cast
	local pinged = group(ping)
	Alpha(pinged, 0, PING, PING_UP, 1, nil, "OUT")
	Alpha(pinged, PING, 0, PING_DOWN, 2, nil, "OUT")
	Park(pinged, ping, 0)
	self.pinged = pinged

	-- A spark that runs the line over and over: held, in, across (gone before
	-- the end), held.
	local function runner(f, t)
		local g = group(f, "REPEAT")
		Alpha(g, 0, 0, t.hold, 1)
		Alpha(g, 0, t.peak, t.up, 2, nil, "OUT")
		g.run = Slide(g, t.run, 3, "IN_OUT")
		Alpha(g, t.peak, 0, t.down, 3, t.run - t.down, "IN")
		Alpha(g, 0, 0, t.rest, 4)
		Park(g, f, 0)
		return g
	end
	self.patrol = runner(self.rover, PATROL)
	self.drift = runner(self.glint, DRIFT)
	self.idle[#self.idle + 1] = self.drift
	-- The line's breath while somebody is owed: everything inside the cut, so
	-- the cast's own fade and the breath never write the one frame.
	local breath = group(clip, "BOUNCE")
	Alpha(breath, 1, BREATH_LO, BREATH, 1, nil, "IN_OUT")
	Park(breath, clip, 1)
	self.breath = breath

	-- A landing: the spark dashes the line and the line flashes.
	local dash = group(self.spark)
	Alpha(dash, 0, 1, 0.02, 1)
	dash.run = Slide(dash, DASH, 2, "OUT")
	Alpha(dash, 1, 0, DASH_DOWN, 2, DASH - DASH_DOWN, "IN")
	Park(dash, self.spark, 0)
	self.dash = dash
	local flash = group(hot)
	Alpha(flash, 0, HOT, HOT_UP, 1, nil, "OUT")
	Alpha(flash, HOT, 0, HOT_DOWN, 2, nil, "OUT")
	Park(flash, hot, 0)
	self.flash = flash
	-- The mark: up at once, held while it is struck and read, let go.
	local stamp = group(badge)
	Alpha(stamp, 0, 1, STAMP_UP, 1)
	Alpha(stamp, 1, 1, STAMP_HOLD, 2)
	Alpha(stamp, 1, 0, STAMP_DOWN, 3, nil, "IN")
	Park(stamp, badge, 0)
	self.stamp = stamp

	-- A refusal: the red line sputters and runs back out to the left, the
	-- cast undone, then comes back in the reason's colour. A slide ends where
	-- it began, so the fill is put at nothing as the run ends and faded up
	-- from there. However the sputter ends, the red goes with it.
	local back = group(fill)
	back.fade = Alpha(back, 0, REST, BACK, 1, nil, "OUT")
	Park(back, fill, level)
	self.back = back
	local sputter = group(fill)
	Alpha(sputter, 1, SPUTTER_LOW, SPUTTER[1], 1)
	Alpha(sputter, SPUTTER_LOW, 1, SPUTTER[2], 2)
	Alpha(sputter, 1, 1, SPUTTER[3], 3)
	Alpha(sputter, 1, SPUTTER_END, SPUTTER[4], 4, nil, "IN")
	sputter.out = Slide(sputter, SPUTTER[4], 4, "IN")
	sputter:SetScript("OnFinished", function()
		self.broken = nil
		self:Recolour()
		fill:SetAlpha(0)
		back.fade:SetToAlpha(level())
		Replay(back)
	end)
	sputter:SetScript("OnStop", function()
		self.broken = nil
		self:Recolour()
		fill:SetAlpha(level())
	end)
	self.sputter = sputter

	-- The colours that never change.
	for _, t in ipairs(self.track) do Colour(t, TRACK[1], TRACK[2], TRACK[3], TRACK_ALPHA) end
	Colour(self.glow, 1, 1, 1, 0)
	Colour(self.check, TICK_COLOUR[1], TICK_COLOUR[2], TICK_COLOUR[3])
	Colour(self.cross, CROSS_COLOUR[1], CROSS_COLOUR[2], CROSS_COLOUR[3])
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

---------------------------------------------------------------------------
-- layout
---------------------------------------------------------------------------

-- A line's three pieces laid in `box`, caps `cap` wide, the hairline between
-- them, all three `tall` and on the box's foot: one height, so the client
-- rounds them to the screen alike and the hairline runs straight through.
local function PlaceBar(b, box, cap, tall)
	for _, t in ipairs(b) do t:ClearAllPoints() end
	b[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	b[1]:SetSize(cap, tall)
	b[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	b[3]:SetSize(cap, tall)
	b[2]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", cap, 0)
	b[2]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -cap, 0)
	b[2]:SetHeight(tall)
end

function Minimal:Apply(p, above)
	local kit = self.kit
	local art = kit.art
	local W, H = p.width, p.height
	-- Where the words start: Panel.lua has just placed them (Text.lua,
	-- PlaceLines), and never nearer the right edge than thirty units, so
	-- there is always a line's worth of room.
	local left = kit.fit.left or 0
	local k = math.max(SCALE_LO, math.min(SCALE_HI, H / SCALE_AT))
	local cap = CAP_W * k
	-- The ticks' outer edges: flush with the words' left, and LINE_END short
	-- of the panel's right.
	local x0, x1 = left, W - LINE_END
	-- Switched off: Minimal as it was.
	if p.minimalLine == false then
		self:Down()
		return
	end
	self.active = true
	self.frame:Show()

	-- The line's box: the caps' outer edges stand TICK_X less half a stroke
	-- outside the ticks', and its foot hangs under the panel's by what the
	-- file keeps empty under its light.
	local out = (TICK_X - CORE) * k
	local wide = x1 - x0 + 2 * out
	local box = self.box
	box:ClearAllPoints()
	box:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", x0 - out, (LINE_UP - LINE_MID) * k)
	box:SetSize(wide, CAP_H * k)
	-- The cut (CUT_KEEP, FLARE): from just outside the left tick to a spark's
	-- flare past the far one, and as tall as the spark, whose lens stands over
	-- the line and under it. `under` is how far the spark's foot hangs below
	-- the box's.
	local cut, under = out - CUT_KEEP * k, (SPARK_H / 2 - LINE_MID) * k
	local clip = self.clip
	clip:ClearAllPoints()
	clip:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", cut, -under)
	clip:SetSize(wide - cut + FLARE * k, SPARK_H * k)
	PlaceBar(self.track, box, cap, CAP_H * k)
	PlaceBar(self.fillBar, self.fill, cap, CAP_H * k)
	PlaceBar(self.hotBar, self.hot, cap, CAP_H * k)
	-- The glow: from tick to tick, its middle on the hairline's.
	self.glow:ClearAllPoints()
	self.glow:SetPoint("BOTTOMLEFT", self.fill, "BOTTOMLEFT", TICK_X * k, -(GLOW_H / 2 - LINE_MID) * k)
	self.glow:SetPoint("BOTTOMRIGHT", self.fill, "BOTTOMRIGHT", -TICK_X * k, -(GLOW_H / 2 - LINE_MID) * k)
	self.glow:SetHeight(GLOW_H * k)
	self.ping:ClearAllPoints()
	self.ping:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	self.ping:SetSize(cap, CAP_H * k)

	-- The sparks, laid against the line's box (the cut is not where the line
	-- starts). The cast's and the landing's has its head on the left tick, and
	-- the tick-to-tick distance to dash; cast, it starts a tick further back,
	-- where the fill's leading end starts, and runs the fill's whole slide
	-- with it. The two that fade in standing still start START_IN inside the
	-- tick and run the rest of the way to the far one.
	local run = wide - 2 * TICK_X * k
	local roam = run - START_IN * k
	for _, f in ipairs({ self.spark, self.rover, self.glint }) do
		local inside = f == self.spark and 0 or START_IN
		f:ClearAllPoints()
		f:SetSize(SPARK_W * k, SPARK_H * k)
		f:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", (TICK_X + inside - SPARK_HEAD * SPARK_W) * k, -under)
	end
	self.fillIn.away:SetOffset(-wide, 0)
	self.fillIn.home:SetOffset(wide, 0)
	self.sputter.out:SetOffset(-wide, 0)
	self.cast.away:SetOffset(-2 * TICK_X * k, 0)
	self.cast.run:SetOffset(wide, 0)
	self.patrol.run:SetOffset(roam, 0)
	self.drift.run:SetOffset(roam, 0)
	self.dash.run:SetOffset(run, 0)

	-- The mark, on the icon's lower right corner (which Panel.lua has placed).
	self.showIcon = p.showIcon and true or false
	if self.showIcon then
		local size = math.max(MARK_LEAST, p.iconSize * MARK_SIZE)
		self.badge:ClearAllPoints()
		self.badge:SetSize(size, size)
		self.badge:SetPoint("CENTER", kit.icon, "BOTTOMRIGHT", -p.iconSize * MARK_IN, p.iconSize * MARK_IN)
		self.badge:Show()
	else
		self.badge:Hide()
	end

	self.combat, self.rested = nil, nil
	if not (self.fillIn:IsPlaying() or self.sputter:IsPlaying() or self.back:IsPlaying()) then
		self.fill:SetAlpha(self.owed and OWED or REST)
	end
	self:Recolour()
	self:Rest()
end

-- Everything stopped and out of sight, the dressing still worn: the line
-- switched off.
function Minimal:Down()
	self.active, self.owed, self.rested, self.broken = nil, nil, nil, nil
	self.flow:StopAll()
	for _, g in ipairs(self.anims) do g:Stop() end
	self.frame:Hide()
end

-- What runs with nobody owed: the glint, on Full effects, out of a fight and
-- with the prompt up; nothing otherwise. Asked at every paint (Painted) and
-- every scan (StopAttention), so it does nothing unless something changed.
function Minimal:Rest()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.owed and 2 or 0)
	if state == self.rested then return end
	self.rested = state
	if on and not self.owed then
		if not self.drift:IsPlaying() then self.drift:Play() end
	else
		Stop(self.drift)
	end
end

-- Every paint of a person: the prompt is up, so what runs at rest may run.
function Minimal:Painted()
	self:Rest()
end

function Minimal:Hide()
	if not self.kit then return end
	self.combat = nil
	self:Down()
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- Every colour goes through Colour (Looks.lua, ONE ALPHA): the game keeps one
-- alpha for a texture, and a colour given any other way would write over it.
function Minimal:PaintReason(r, g, b, reason, mode)
	self.r, self.g, self.b, self.mode = r, g, b, mode
	self:Recolour()
end

function Minimal:Recolour()
	local kit = self.kit
	local r, g, b = self.r, self.g, self.b
	if not r or self.mode == "off" then r, g, b = WARM[1], WARM[2], WARM[3] end
	-- A refusal's red stays on the line until its sputter is over.
	if not self.broken then
		local fr, fg, fb = kit.Tint(r, g, b, FILL_LIFT)
		for _, t in ipairs(self.fillBar) do Colour(t, fr, fg, fb) end
		-- The glow's strength is its own alpha, given with its colour: lit
		-- while somebody is owed, at nothing otherwise.
		Colour(self.glow, r, g, b, self.owed and GLOW or 0)
	end
	local sr, sg, sb = kit.Tint(r, g, b, 0.70)
	Colour(self.spark.tex, sr, sg, sb)
	Colour(self.rover.tex, sr, sg, sb)
	Colour(self.glint.tex, sr, sg, sb)
	local hr, hg, hb = kit.Tint(r, g, b, 0.55)
	for _, t in ipairs(self.hotBar) do Colour(t, hr, hg, hb) end
	Colour(self.pingCap, hr, hg, hb)
end

---------------------------------------------------------------------------
-- somebody owed
---------------------------------------------------------------------------

function Minimal:Attention(isNew, arrived, flashStyle)
	if flashStyle == "off" or self.combat or not self.active then
		self:StopAttention()
		return
	end
	local full = self.kit.FullEffects()
	local was = self.owed
	self.owed = true
	if not was then self:Recolour() end
	self:Rest()
	-- Somebody new on top: the line is cast for them. On Calm it stands lit.
	if full and (isNew or not was) and not self.sputter:IsPlaying() then
		Stop(self.back)
		Stop(self.dash)
		Replay(self.fillIn)
		Replay(self.cast)
	elseif not (self.fillIn:IsPlaying() or self.sputter:IsPlaying() or self.back:IsPlaying()) then
		self.fill:SetAlpha(OWED)
	end
	if full and flashStyle == "pulse" then
		if not self.breath:IsPlaying() then self.breath:Play() end
		if not self.patrol:IsPlaying() then self.patrol:Play() end
	else
		Stop(self.breath)
		Stop(self.patrol)
	end
end

-- Run by nearly every scan (nobody owed is the usual case): with nobody owed
-- already, it only asks whether the glint may run.
function Minimal:StopAttention()
	if not self.kit then return end
	if self.owed then
		self.owed = nil
		Stop(self.fillIn)
		Stop(self.cast)
		Stop(self.pinged)
		Stop(self.breath)
		Stop(self.patrol)
		if not (self.sputter:IsPlaying() or self.back:IsPlaying()) then self.fill:SetAlpha(REST) end
		self:Recolour()
	end
	if self.active then self:Rest() end
end

---------------------------------------------------------------------------
-- an outcome
---------------------------------------------------------------------------

-- The tick or the cross struck onto the icon's corner.
function Minimal:Strike(cross)
	if not self.showIcon then return end
	self.check:SetShown(not cross)
	self.cross:SetShown(cross)
	self.checkSheet:Stop()
	self.crossSheet:Stop()
	local sheet = cross and self.crossSheet or self.checkSheet
	sheet:Play()
	Replay(self.stamp)
end

function Minimal:Flourish(kind)
	if self.combat or not self.active then return end
	if kind == "cast" then
		-- A cast still filling is finished by the landing: the line whole.
		Stop(self.fillIn)
		Stop(self.cast)
		Replay(self.dash)
		Replay(self.flash)
		self:Strike(false)
	elseif kind == "failed" then
		Stop(self.fillIn)
		Stop(self.cast)
		Stop(self.back)
		-- Stopped first: its stop puts the reason's colour back, and the red
		-- goes on after.
		self.sputter:Stop()
		self.broken = true
		for _, t in ipairs(self.fillBar) do Colour(t, BREAK[1], BREAK[2], BREAK[3]) end
		Colour(self.glow, BREAK[1], BREAK[2], BREAK[3], GLOW)
		self.sputter:Play()
		self:Strike(true)
	end
end

function Minimal:StopFlourishes()
	if not self.kit then return end
	Stop(self.dash)
	Stop(self.flash)
	Stop(self.sputter)
	Stop(self.back)
	Stop(self.stamp)
	self.checkSheet:Stop()
	self.crossSheet:Stop()
end

-- The fight holds the panel: the loops stop and the line rests. Prompt dims
-- the art, and the line with it.
function Minimal:Combat(on)
	on = on and true or false
	if (self.combat or false) == on or not self.kit then return end
	self.combat = on or nil
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
	if self.active then self:Rest() end
end
