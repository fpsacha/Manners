-- Manners -- the prompt's animations: the entrance, the text's cross-fade and
-- shake, the favour's glow and sweep, a landed buff's rings and light, the fade
-- out after the last buff, the cooldown sweep and the dim for a fight.
--
-- Every gesture means one thing and moves one way:
--   * a favour ARRIVING converges: the icon's echo drops onto it and a bloom
--     of the reason's light gathers round its ring (under 0.5 s);
--   * a buff LANDING radiates: rings spread from the icon, a band of the
--     reason's light crosses the panel, the glow flares, the panel settles
--     (under 0.7 s);
--   * a REFUSAL contracts and shakes: a red-amber ring snaps in on the icon
--     and the text shakes its head, the shakes dying away (0.3 s);
--   * somebody OWED breathes: the reason's light and a warm white rim, a slow
--     2.4 s breath, never a flash.
-- All of it plays on frames of the art, which is not protected: nothing here
-- touches the secure button or the rows, in a fight or out of one. Nothing is
-- polled; every group is started by an event (an arrival, an outcome, a
-- cooldown) and parks what it lit at nothing when it ends or is stopped.
-- "Calm" is fades only: no scale, no shake, no rings, no light across.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local OUTCOME_SECONDS, Gradient, Try, PaintHalo = lib.OUTCOME_SECONDS, lib.Gradient, lib.Try, lib.PaintHalo
local RING, RING_SQ, RING_AT, Tint, WARM_WHITE = lib.RING, lib.RING_SQ, lib.RING_AT, lib.Tint, lib.WARM_WHITE

-- Whether the panel is dimmed for combat, so the alpha is written once per
-- transition.
local combatHeld

---------------------------------------------------------------------------
-- building blocks
---------------------------------------------------------------------------

-- Each adds one animation to `group` and hands it back. A method this client
-- lacks leaves that detail out, never the group: all five clients have them.
local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Grow(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Scale")
	if a.SetScaleFrom then a:SetScaleFrom(from, from) end
	if a.SetScaleTo then a:SetScaleTo(to, to) end
	if a.SetOrigin then a:SetOrigin("CENTER", 0, 0) end
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- An animation leaves the frame at its final value, so what it lit is parked
-- back at invisible when it finishes and when it is stopped.
local function Park(group, frame)
	local function park() frame:SetAlpha(0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Playing(group)
	return group and group:IsPlaying()
end

---------------------------------------------------------------------------
-- the gestures every look shares: rings, the icon's echo
--
-- Built on frames anchored to the icon, so a look draws them over its own
-- icon wherever it puts it, in its own ring art. Looks/Looks.lua hands the
-- builder over as kit.FX.
---------------------------------------------------------------------------

-- The echo and the rings, in seconds.
local ECHO_IN, ECHO_OUT = 0.16, 0.20
local RING_SECONDS = { 0.52, 0.46 }
local RING_DELAY = { 0, 0.08 }
local RING_REACH = { 1.55, 1.38 }
local RING_PEAK = { 0.95, 0.60 }
local REJECT_SECONDS = 0.30

local FXMethods = {}
FXMethods.__index = FXMethods

-- `noEcho`: the look keeps its icon clean, so there is no echo to drop on it.
local function NewFX(parent, level, noEcho)
	local fx = setmetatable({ rings = {} }, FXMethods)
	local function frame()
		local f = CreateFrame("Frame", nil, parent)
		f:SetAlpha(0)
		if level then f:SetFrameLevel(level) end
		return f
	end

	-- Two rings, the second a beat behind and shorter, so a landing reads as
	-- a pulse rather than a single hoop. The first also snaps in when a
	-- refusal contracts onto the icon.
	for i = 1, 2 do
		local ring = { frame = frame() }
		ring.tex = ring.frame:CreateTexture(nil, "OVERLAY", nil, 3)
		ring.tex:SetTexture(RING_SQ)
		ring.tex:SetBlendMode("ADD")
		ring.tex:SetAllPoints(ring.frame)
		local land = ring.frame:CreateAnimationGroup()
		Grow(land, 1, RING_REACH[i], RING_SECONDS[i], 1, RING_DELAY[i], "OUT")
		Alpha(land, RING_PEAK[i], 0, RING_SECONDS[i], 1, RING_DELAY[i], "IN")
		Park(land, ring.frame)
		ring.land = land
		if i == 1 then
			local reject = ring.frame:CreateAnimationGroup()
			Grow(reject, 1.55, 0.97, REJECT_SECONDS, 1, 0, "OUT")
			Alpha(reject, 0, 0.95, 0.07, 1, 0, "OUT")
			Alpha(reject, 0.95, 0, REJECT_SECONDS - 0.07, 1, 0.07, "IN")
			Park(reject, ring.frame)
			ring.reject = reject
		end
		fx.rings[i] = ring
	end

	fx.frames = { fx.rings[1].frame, fx.rings[2].frame }
	if noEcho then return fx end

	-- The icon's echo: a copy of the spell, added over the icon, dropping onto
	-- it from larger and settling out again. Its own frame holds its own
	-- mask, so the two scale together.
	local echo = { frame = frame() }
	echo.tex = echo.frame:CreateTexture(nil, "OVERLAY", nil, 4)
	echo.tex:SetBlendMode("ADD")
	echo.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	echo.tex:SetAllPoints(echo.frame)
	if echo.frame.CreateMaskTexture and echo.tex.AddMaskTexture then
		echo.mask = echo.frame:CreateMaskTexture()
		echo.mask:SetAllPoints(echo.frame)
	end
	local drop = echo.frame:CreateAnimationGroup()
	Grow(drop, 1.45, 1, ECHO_IN, 1, 0, "OUT")
	Alpha(drop, 0, 0.62, ECHO_IN * 0.7, 1, 0, "OUT")
	Grow(drop, 1, 1.10, ECHO_OUT, 2, 0, "IN_OUT")
	Alpha(drop, 0.62, 0, ECHO_OUT, 2, 0, "IN")
	Park(drop, echo.frame)
	echo.drop = drop
	fx.echo = echo
	fx.frames[3] = echo.frame
	return fx
end

-- Placed round `icon`: the rings' frames `pad` outside it (their texture fills
-- them, so pad says where the ring sits), the echo's frame on it.
function FXMethods:Place(icon, pad)
	for _, ring in ipairs(self.rings) do
		ring.frame:ClearAllPoints()
		ring.frame:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
		ring.frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)
	end
	local echo = self.echo
	if not echo then return end
	echo.frame:ClearAllPoints()
	echo.frame:SetAllPoints(icon)
end

-- The pad that puts the thin ring's middle `gap` units outside an icon of
-- `size` units: the file keeps its ring at RING_AT of its half-width.
function FXMethods.ThinPad(size, gap)
	return (size / 2 + gap) / RING_AT - size / 2
end

-- The ring's art, round or square, and the echo's shape (a mask file, or nil
-- for a square icon). Called whenever the icon's shape may have changed.
function FXMethods:Shape(round, roundFile, squareFile, maskFile)
	for _, ring in ipairs(self.rings) do
		ring.tex:SetTexture(round and roundFile or squareFile)
	end
	local echo = self.echo
	if not (echo and echo.mask) then return end
	if maskFile then
		echo.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		echo.mask:Show()
		if not echo.masked then
			echo.tex:AddMaskTexture(echo.mask)
			echo.masked = true
		end
	elseif echo.masked then
		echo.tex:RemoveMaskTexture(echo.mask)
		echo.mask:Hide()
		echo.masked = nil
	end
end

function FXMethods:SetShown(on)
	for _, f in ipairs(self.frames) do f:SetShown(on) end
end

-- A buff landed: two rings spread from the icon in the colour, the second
-- paler. `strength` (default 1) is how much of the art's light a look that
-- wants restraint lets through.
function FXMethods:Land(r, g, b, strength)
	self:Stop()
	local k = strength or 1
	local r2, g2, b2 = Tint(r, g, b, 0.45)
	self.rings[1].tex:SetVertexColor(r, g, b, k)
	self.rings[2].tex:SetVertexColor(r2, g2, b2, k)
	for _, ring in ipairs(self.rings) do ring.land:Play() end
end

-- A refusal: one ring snaps in onto the icon.
function FXMethods:Refuse(r, g, b, strength)
	self:Stop()
	self.rings[1].tex:SetVertexColor(r, g, b, strength or 1)
	self.rings[1].reject:Play()
end

-- A favour arrived: the icon's echo, the spell `file`, in the colour taken
-- towards white, drops onto the icon.
function FXMethods:Arrive(file, r, g, b)
	local echo = self.echo
	if not (echo and file) then return end
	echo.drop:Stop()
	echo.tex:SetTexture(file)
	echo.tex:SetVertexColor(r, g, b, 1)
	echo.drop:Play()
end

function FXMethods:Stop()
	for _, ring in ipairs(self.rings) do
		ring.land:Stop()
		if ring.reject then ring.reject:Stop() end
	end
	if self.echo then self.echo.drop:Stop() end
end

function FXMethods:IsPlaying()
	for _, ring in ipairs(self.rings) do
		if Playing(ring.land) or Playing(ring.reject) then return true end
	end
	return self.echo ~= nil and Playing(self.echo.drop)
end

lib.NewFX = NewFX

---------------------------------------------------------------------------
-- the three looks drawn here
---------------------------------------------------------------------------

function Prompt:BuildAnimations()
	-- Entrance: rise into place, fade in and settle. A translation (and a scale)
	-- is undone when its group ends, so the drop comes first, instantly, and
	-- the rise ends exactly where the panel belongs, with no hop at the end.
	-- The panel grows a little past its size and comes back, so it lands
	-- rather than slides: 0.33 s in all.
	local intro = R.art:CreateAnimationGroup()
	Alpha(intro, 0, 0, 0.01, 1)
	Slide(intro, 0, -8, 0.01, 1)
	Grow(intro, 0.95, 0.95, 0.01, 1)
	Alpha(intro, 0, 1, 0.22, 2, 0, "OUT")
	Slide(intro, 0, 8, 0.22, 2, 0, "OUT")
	Grow(intro, 0.95, 1.025, 0.22, 2, 0, "OUT")
	Grow(intro, 1.025, 1, 0.11, 3, 0, "IN_OUT")
	R.art.intro = intro

	-- The same on Calm: a fade, nothing that moves or grows.
	local introCalm = R.art:CreateAnimationGroup()
	Alpha(introCalm, 0, 1, 0.20, 1, 0, "OUT")
	R.art.introCalm = introCalm

	-- The panel settling as a buff lands: a small swell and back, after the
	-- light has started across it.
	local settle = R.art:CreateAnimationGroup()
	Grow(settle, 1, 1.03, 0.10, 1, 0.06, "OUT")
	Grow(settle, 1.03, 1, 0.20, 2, 0, "IN_OUT")
	R.art.settle = settle

	-- Target change: dip the text rather than swapping it under the eye.
	local swap = R.textLayer:CreateAnimationGroup()
	Alpha(swap, 1, 0.15, 0.07, 1)
	Alpha(swap, 0.15, 1, 0.13, 2, 0, "OUT")
	R.textLayer.swap = swap

	-- Favour arrival: the stripe catches the light.
	local sweepAnim = R.sweepFrame:CreateAnimationGroup()
	Alpha(sweepAnim, 0, 0.85, 0.08, 1)
	local sMove = Slide(sweepAnim, 0, 0, 0.40, 2, 0, "IN_OUT")
	Alpha(sweepAnim, 0.85, 0, 0.40, 2)
	sweepAnim.move = sMove
	-- An animation leaves the frame at its final value, so park it back at
	-- invisible or the stripe keeps a bright block stuck to it.
	Park(sweepAnim, R.sweepFrame)
	R.sweepFrame.anim = sweepAnim

	-- The arrival's bloom: the reason's light gathers round the ring, in and
	-- out within half a second.
	local arrive = R.burstFrame:CreateAnimationGroup()
	Alpha(arrive, 0, 0.90, 0.09, 1, 0, "OUT")
	Alpha(arrive, 0.90, 0, 0.38, 1, 0.09, "OUT")
	Grow(arrive, 0.94, 1.10, 0.47, 1, 0, "OUT")
	Park(arrive, R.burstFrame)
	R.burstFrame.arrive = arrive

	-- A buff that landed: the halo flares and fades as the rings go out.
	local burst = R.burstFrame:CreateAnimationGroup()
	Alpha(burst, 0, 0.85, 0.07, 1, 0, "OUT")
	Alpha(burst, 0.85, 0, 0.38, 1, 0.07, "OUT")
	Grow(burst, 1, 1.10, 0.45, 1, 0, "OUT")
	Park(burst, R.burstFrame)
	R.burstFrame.anim = burst

	-- A refusal: the same halo, a short hot flare in red and amber.
	local reject = R.burstFrame:CreateAnimationGroup()
	Alpha(reject, 0, 0.80, 0.05, 1, 0, "OUT")
	Alpha(reject, 0.80, 0, 0.25, 1, 0.05, "IN")
	Park(reject, R.burstFrame)
	R.burstFrame.reject = reject

	-- The once-only flash, for "Flash once": the halo and the rim lit and let go.
	local glowAnim = R.glowFrame:CreateAnimationGroup()
	Alpha(glowAnim, 0, 0.70, 0.10, 1)
	Alpha(glowAnim, 0.70, 0, 0.45, 2, 0, "OUT")
	Park(glowAnim, R.glowFrame)
	R.glowFrame.anim = glowAnim
	local rimAnim = R.rimFrame:CreateAnimationGroup()
	Alpha(rimAnim, 0, 0.60, 0.10, 1)
	Alpha(rimAnim, 0.60, 0, 0.45, 2, 0, "OUT")
	Park(rimAnim, R.rimFrame)
	R.rimFrame.anim = rimAnim

	-- Keeps breathing for as long as somebody is still owed, so it is not
	-- missed: the reason's light and, a little inside it, a warm white rim, on
	-- the same slow breath (2.4 s in and out, 1.2 s each way).
	local pulse = R.glowFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	Alpha(pulse, 0.14, 0.62, 1.2, 1, 0, "IN_OUT")
	pulse:SetScript("OnStop", function() R.glowFrame:SetAlpha(0) end)
	R.glowFrame.pulse = pulse
	local rimPulse = R.rimFrame:CreateAnimationGroup()
	rimPulse:SetLooping("BOUNCE")
	Alpha(rimPulse, 0.04, 0.42, 1.2, 1, 0, "IN_OUT")
	rimPulse:SetScript("OnStop", function() R.rimFrame:SetAlpha(0) end)
	R.rimFrame.pulse = rimPulse

	-- Light crossing the panel once, left to right: in, across, out, with a
	-- bright leading edge. The distance is the panel's width, which ApplyStyle
	-- knows and sets.
	local shine = R.shineFrame:CreateAnimationGroup()
	Alpha(shine, 0, 1, 0.07, 1)
	local shMove = Slide(shine, 0, 0, 0.46, 2, 0, "IN_OUT")
	Alpha(shine, 1, 0, 0.46, 2, 0, "IN")
	shine.move = shMove
	Park(shine, R.shineFrame)
	R.shineFrame.anim = shine

	-- A refusal: the text shakes its head, the shakes dying away (they sum to
	-- nothing, and the group's end puts it home).
	local shake = R.textLayer:CreateAnimationGroup()
	for i, dx in ipairs({ -3, 5, -5, 4, -2, 1 }) do
		Slide(shake, dx, 0, 0.045, i)
	end
	R.textLayer.shake = shake

	-- Leaving after the last buff: the panel fades over the second half of the
	-- confirmation. The button is still hidden when the confirmation runs out;
	-- art is parked invisible until then, and the next Refresh restores the
	-- alpha.
	local outro = R.art:CreateAnimationGroup()
	Alpha(outro, 1, 0, OUTCOME_SECONDS * 0.5, 1, OUTCOME_SECONDS * 0.5, "IN")
	outro:SetScript("OnFinished", function()
		R.art.faded = true
		R.art:SetAlpha(0)
	end)
	R.art.outro = outro

	-- A fade cancelled part-way, brought back to rest rather than snapped: when
	-- somebody arrives while the panel is fading out, or a fight starts (the
	-- button cannot be hidden in combat). From and to are set for each play.
	local comeback = R.art:CreateAnimationGroup()
	local cFade = comeback:CreateAnimation("Alpha")
	cFade:SetDuration(0.18)
	if cFade.SetSmoothing then cFade:SetSmoothing("OUT") end
	comeback.fade = cFade
	R.art.comeback = comeback
end

-- Whether the extra motion is wanted: the landing rings, the shine, the
-- shake, the settle, the echo, the scale of the entrance and the outro.
-- "Calm" drops all of it; what is left is fades (the entrance, the text's
-- cross-fade, the arrival's stripe and glow, the breath).
local function FullEffects()
	local p = ns.db and ns.db.profile.prompt
	return p ~= nil and p.effects ~= "calm"
end

-- The alpha art rests at: dimmed for a fight, full otherwise. The outro leaves
-- art at zero, and every way back has to undo that.
local function RestArtAlpha()
	R.art.faded = nil
	R.art:SetAlpha(combatHeld and (S.activeLook and S.activeLook.combatArtAlpha or 0.55) or 1)
end

-- The entrance: the full one lands, Calm's fades. Played where the panel
-- comes up.
function Prompt:PlayIntro()
	if not R.art.intro then return end
	if FullEffects() then
		R.art.introCalm:Stop()
		R.art.intro:Play()
	else
		R.art.intro:Stop()
		R.art.introCalm:Play()
	end
end

function Prompt:StopOutro()
	if R.art.outro and R.art.outro:IsPlaying() then R.art.outro:Stop() end
	if R.art.faded then RestArtAlpha() end
	R.art.outroFor = nil
end

-- How far the outro has taken art, worked out from when it started: what
-- GetAlpha answers mid-animation has not been seen to settle on this client.
-- Same shape as the fade: a wait, then an eased-in fall.
local function OutroAlpha()
	if R.art.faded then return 0 end
	if not (R.art.outro and R.art.outro:IsPlaying() and R.art.outroAt) then return nil end
	local wait = OUTCOME_SECONDS * 0.5
	local t = (GetTime() - R.art.outroAt - wait) / (OUTCOME_SECONDS * 0.5)
	if t <= 0 then return 1 end
	if t >= 1 then return 0 end
	return 1 - t * t
end

-- Restarted for each new outcome: a second one (a refusal just after a landed
-- buff) would otherwise paint onto a panel already faded, or be cut short.
function Prompt:PlayOutro(stamp)
	if R.art.outroFor == stamp then return end
	self:StopOutro()
	if R.art.comeback and R.art.comeback:IsPlaying() then R.art.comeback:Stop() end
	R.art.outroFor, R.art.outroAt = stamp, GetTime()
	R.art.outro:Play()
end

-- A fade a repaint just cancelled, taken back to rest over a moment; `from` is
-- nil when no fade was running.
function Prompt:ComeBack(from)
	self:StopOutro()
	local rest = combatHeld and (S.activeLook and S.activeLook.combatArtAlpha or 0.55) or 1
	if from == nil or math.abs(from - rest) < 0.02 then return end
	if not (R.art.comeback and R.button:IsShown()) then return end
	R.art.comeback:Stop()
	R.art.comeback.fade:SetFromAlpha(from)
	R.art.comeback.fade:SetToAlpha(rest)
	R.art.comeback:Play()
end

-- The once-only effects, stopped: what a repaint about somebody else does to a
-- flash that belonged to the last thing on the panel.
function Prompt:StopFlourishes()
	for _, g in ipairs({ R.burstFrame.anim, R.burstFrame.arrive, R.burstFrame.reject, R.shineFrame.anim,
		R.textLayer.shake, R.art.settle }) do
		if g and g:IsPlaying() then g:Stop() end
	end
	if R.fx then R.fx:Stop() end
	if S.activeLook then S.activeLook:StopFlourishes() end
end

-- The band of light across the panel, brighter for a landed buff than for an
-- arrival. Not on the Minimal look: additive light with no panel under it is a
-- white column sweeping over the world.
function Prompt:PlayShine(r, g, b, strength)
	if not R.shineFrame.anim then return end
	if ns.db and ns.db.profile.prompt.style == "minimal" then return end
	R.shineBand:SetVertexColor(r, g, b, strength)
	R.shineFrame.anim:Stop()
	R.shineFrame.anim:Play()
end

-- The cooldown sweep, brought up to date when a cast goes out and when the
-- panel comes up; the Cooldown frame animates itself in between.
function Prompt:SyncCooldown()
	if not R.cooldown then return end
	local p = ns.db and ns.db.profile.prompt
	-- Not in a fight with "Stay quiet in combat" on, which promises a still
	-- panel. The Cooldown frame is not protected, so hiding it in combat is
	-- allowed; SetCombatHold asks again as the fight starts and ends.
	local quiet = p and p.hideInCombat and InCombatLockdown()
	if not (p and p.showCooldown and p.showIcon) or quiet then
		Try(R.cooldown, "Clear")
		R.cooldown:Hide()
		return
	end
	local start, duration
	local span = ns.GlobalCooldownSpan
	if span then start, duration = span(GetTime()) end
	if start and duration and duration > 0 and Try(R.cooldown, "SetCooldown", start, duration) then
		R.cooldown:Show()
	else
		Try(R.cooldown, "Clear")
		R.cooldown:Hide()
	end
end

-- Run by nearly every scan (nobody owed is the usual case), so it builds
-- nothing: no table, no closure.
function Prompt:StopAttention()
	local glow, rim = R.glowFrame, R.rimFrame
	if glow.pulse and glow.pulse:IsPlaying() then glow.pulse:Stop() end
	glow:SetAlpha(0)
	-- The rim parks itself when its breath stops (OnStop), so only a breath
	-- that is running needs the call.
	if rim.pulse and rim.pulse:IsPlaying() then rim.pulse:Stop() end
	if S.activeLook then S.activeLook:StopAttention() end
end

-- The reason's light and the warm white rim, in the arrival's colour.
local function ArrivalColour(self, p)
	if (p.accentMode or "icon") == "off" then return 1, 1, 1 end
	return self:AccentColor("owed")
end

-- `isNew`: somebody owed has just become the one on the panel (the flash and
-- the sweep). `arrived`: the favour itself was only just done (the light). See
-- Refresh.
function Prompt:StartAttention(isNew, arrived)
	local p = ns.db.profile.prompt
	local mode = p.flashStyle or "pulse"
	-- A look of its own answers all of it; the light only on a favour just
	-- done, never over an outcome.
	if S.activeLook then
		return S.activeLook:Attention(isNew, arrived and not self:OutcomeLive(), mode)
	end
	if mode == "off" then
		self:StopAttention()
		return
	end

	-- The stripe's sweep first, whatever the icon is doing: it has nothing to
	-- do with the icon.
	if isNew and R.sweepFrame.anim and R.sweepFrame:IsShown() then
		R.sweepFrame.anim:Stop()
		R.sweepFrame.anim.move:SetOffset(0, -(p.height - 14))
		R.sweepFrame.anim:Play()
	end

	-- And the panel catches the light once as the favour is done, in the reason
	-- colour (plain light with accents off). Never over an outcome or over
	-- light already crossing, so a press's own confirmation is not cut off.
	if arrived and FullEffects() and not self:OutcomeLive()
		and not (R.shineFrame.anim and R.shineFrame.anim:IsPlaying()) then
		local r, g, b = ArrivalColour(self, p)
		r, g, b = Tint(r, g, b, 0.45)
		self:PlayShine(r, g, b, 0.20)
	end

	-- The glow is drawn around the icon, so it goes with it.
	if not p.showIcon then
		self:StopAttention()
		return
	end

	-- The favour just landed on the panel: the icon's echo drops onto it and
	-- the reason's light gathers round its ring. Full only, and never over an
	-- outcome the panel is still showing.
	if isNew and FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then
		local r, g, b = ArrivalColour(self, p)
		if R.burstFrame.anim:IsPlaying() then R.burstFrame.anim:Stop() end
		PaintHalo(R.burstHalo, r, g, b, 1)
		R.burstFrame.arrive:Stop()
		R.burstFrame.arrive:Play()
		local file = S.current and lib.EntryIcon(S.current)
		R.fx:Arrive(file, Tint(r, g, b, 0.55))
	end

	if mode == "pulse" then
		if R.glowFrame.pulse and not R.glowFrame.pulse:IsPlaying() then
			if R.glowFrame.anim then R.glowFrame.anim:Stop() end
			if R.rimFrame.anim then R.rimFrame.anim:Stop() end
			R.glowFrame.pulse:Play()
			R.rimFrame.pulse:Play()
		end
	else
		-- Unconditionally, before anything else plays: the looping pulse is
		-- only stopped in the branch above, so switching away from Pulse left
		-- it running.
		if R.glowFrame.pulse then R.glowFrame.pulse:Stop() end
		if R.rimFrame.pulse then R.rimFrame.pulse:Stop() end
		if isNew and R.glowFrame.anim then
			R.glowFrame.anim:Stop()
			R.glowFrame.anim:Play()
			R.rimFrame.anim:Stop()
			R.rimFrame.anim:Play()
		end
	end
end

-- The motion for an outcome, once: rings and light for a confirmed buff, a
-- shake and a contracting ring for a refusal, nothing for an unconfirmed cast.
-- None when quiet in combat, on "Calm", or with the panel not shown.
function Prompt:PlayOutcomeFlourish(kind)
	local p = ns.db and ns.db.profile.prompt
	if not p or not FullEffects() then return end
	if InCombatLockdown() and p.hideInCombat then return end
	if not R.button:IsShown() then return end
	self:StopFlourishes()
	if S.activeLook then
		S.activeLook:Flourish(kind)
		if kind == "failed" and R.textLayer.shake then R.textLayer.shake:Play() end
		-- The panel settles as a buff lands, whatever it is drawn in.
		if kind == "cast" then R.art.settle:Play() end
		return
	end
	if kind == "cast" then
		-- Coloured here rather than by PaintAccent: the repaint that follows
		-- is usually about the next person, and the rings belong to this one.
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then
			r, g, b = self:AccentColor(S.current and S.current.reason or "owed")
		end
		if p.showIcon and R.burstFrame.anim then
			PaintHalo(R.burstHalo, r, g, b, 1)
			R.burstFrame.anim:Play()
			R.fx:Land(Tint(r, g, b, 0.20))
		end
		local sr, sg, sb = Tint(r, g, b, 0.55)
		self:PlayShine(sr, sg, sb, 0.30)
		R.art.settle:Play()
	elseif kind == "failed" then
		if p.showIcon and R.burstFrame.reject then
			PaintHalo(R.burstHalo, 1.00, 0.42, 0.20, 1)
			R.burstFrame.reject:Play()
			R.fx:Refuse(1.00, 0.38, 0.22)
		end
		if R.textLayer.shake then R.textLayer.shake:Play() end
	end
end

-- Dim the whole panel for combat, or undo it; remembers what it last did, so a
-- repaint costs nothing.
function Prompt:SetCombatHold(on)
	if combatHeld == on then return end
	combatHeld = on
	-- art, never the button: every visual of the prompt lives on art precisely
	-- so that combat -- which is when this runs -- cannot refuse it.
	RestArtAlpha()
	if S.activeLook then S.activeLook:Combat(on) end
	-- The sweep answers to the fight as well: see SyncCooldown.
	self:SyncCooldown()
end

lib.FullEffects, lib.OutroAlpha = FullEffects, OutroAlpha
