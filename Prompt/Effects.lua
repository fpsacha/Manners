-- Manners -- the prompt's animations: the entrance, the text's cross-fade and
-- shake, the favour's glow and sweep, a landed buff's ring and light, the fade
-- out after the last buff, the cooldown sweep and the dim for a fight.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local OUTCOME_SECONDS, Gradient, Try, PaintHalo = lib.OUTCOME_SECONDS, lib.Gradient, lib.Try, lib.PaintHalo

-- Whether the panel is dimmed for combat, so the alpha is written once per
-- transition.
local combatHeld

function Prompt:BuildAnimations()
	-- Entrance: rise into place and fade in. A translation is undone when its
	-- group ends, so the drop comes first, instantly, and the rise ends exactly
	-- where the panel belongs, with no hop at the end.
	local intro = R.art:CreateAnimationGroup()
	local hold = intro:CreateAnimation("Alpha")
	hold:SetFromAlpha(0)
	hold:SetToAlpha(0)
	hold:SetDuration(0.01)
	hold:SetOrder(1)
	local drop = intro:CreateAnimation("Translation")
	drop:SetOffset(0, -6)
	drop:SetDuration(0.01)
	drop:SetOrder(1)
	local fade = intro:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.20)
	fade:SetOrder(2)
	if fade.SetSmoothing then fade:SetSmoothing("OUT") end
	local rise = intro:CreateAnimation("Translation")
	rise:SetOffset(0, 6)
	rise:SetDuration(0.20)
	rise:SetOrder(2)
	if rise.SetSmoothing then rise:SetSmoothing("OUT") end
	R.art.intro = intro

	-- Target change: dip the text rather than swapping it under the eye.
	local swap = R.textLayer:CreateAnimationGroup()
	local out = swap:CreateAnimation("Alpha")
	out:SetFromAlpha(1)
	out:SetToAlpha(0.15)
	out:SetDuration(0.07)
	out:SetOrder(1)
	local back = swap:CreateAnimation("Alpha")
	back:SetFromAlpha(0.15)
	back:SetToAlpha(1)
	back:SetDuration(0.13)
	back:SetOrder(2)
	if back.SetSmoothing then back:SetSmoothing("OUT") end
	R.textLayer.swap = swap

	-- Favour arrival: the stripe catches the light and the icon warms up.
	local sweepAnim = R.sweepFrame:CreateAnimationGroup()
	local sIn = sweepAnim:CreateAnimation("Alpha")
	sIn:SetFromAlpha(0)
	sIn:SetToAlpha(0.85)
	sIn:SetDuration(0.10)
	sIn:SetOrder(1)
	local sMove = sweepAnim:CreateAnimation("Translation")
	sMove:SetDuration(0.45)
	sMove:SetOrder(2)
	if sMove.SetSmoothing then sMove:SetSmoothing("IN_OUT") end
	local sOut = sweepAnim:CreateAnimation("Alpha")
	sOut:SetFromAlpha(0.85)
	sOut:SetToAlpha(0)
	sOut:SetDuration(0.45)
	sOut:SetOrder(2)
	sweepAnim.move = sMove
	-- An animation leaves the frame at its final value, so park it back at
	-- invisible or the stripe keeps a bright block stuck to it.
	sweepAnim:SetScript("OnFinished", function() R.sweepFrame:SetAlpha(0) end)
	sweepAnim:SetScript("OnStop", function() R.sweepFrame:SetAlpha(0) end)
	R.sweepFrame.anim = sweepAnim

	local glowAnim = R.glowFrame:CreateAnimationGroup()
	local gIn = glowAnim:CreateAnimation("Alpha")
	gIn:SetFromAlpha(0)
	gIn:SetToAlpha(0.55)
	gIn:SetDuration(0.12)
	gIn:SetOrder(1)
	local gOut = glowAnim:CreateAnimation("Alpha")
	gOut:SetFromAlpha(0.55)
	gOut:SetToAlpha(0)
	gOut:SetDuration(0.70)
	gOut:SetOrder(2)
	if gOut.SetSmoothing then gOut:SetSmoothing("OUT") end
	glowAnim:SetScript("OnFinished", function() R.glowFrame:SetAlpha(0) end)
	glowAnim:SetScript("OnStop", function() R.glowFrame:SetAlpha(0) end)
	R.glowFrame.anim = glowAnim

	-- Keeps breathing for as long as somebody is still owed, so it is not
	-- missed.
	local pulse = R.glowFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local breathe = pulse:CreateAnimation("Alpha")
	breathe:SetFromAlpha(0.12)
	breathe:SetToAlpha(0.60)
	breathe:SetDuration(0.85)
	if breathe.SetSmoothing then breathe:SetSmoothing("IN_OUT") end
	pulse:SetScript("OnStop", function() R.glowFrame:SetAlpha(0) end)
	R.glowFrame.pulse = pulse

	-- A buff that landed: the ring pops outward from the icon and fades as it
	-- goes. Short -- a confirmation, not a celebration.
	local burst = R.burstFrame:CreateAnimationGroup()
	local bIn = burst:CreateAnimation("Alpha")
	bIn:SetFromAlpha(0.95)
	bIn:SetToAlpha(0)
	bIn:SetDuration(0.42)
	if bIn.SetSmoothing then bIn:SetSmoothing("IN") end
	local grow = burst:CreateAnimation("Scale")
	Try(grow, "SetScaleFrom", 1, 1)
	Try(grow, "SetScaleTo", 1.35, 1.35)
	Try(grow, "SetOrigin", "CENTER", 0, 0)
	grow:SetDuration(0.42)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	burst:SetScript("OnFinished", function() R.burstFrame:SetAlpha(0) end)
	burst:SetScript("OnStop", function() R.burstFrame:SetAlpha(0) end)
	R.burstFrame.anim = burst

	-- Light crossing the panel once, left to right: in, across, out. The
	-- distance is the panel's width, which ApplyStyle knows and sets.
	local shine = R.shineFrame:CreateAnimationGroup()
	local shIn = shine:CreateAnimation("Alpha")
	shIn:SetFromAlpha(0)
	shIn:SetToAlpha(1)
	shIn:SetDuration(0.10)
	shIn:SetOrder(1)
	local shMove = shine:CreateAnimation("Translation")
	shMove:SetDuration(0.50)
	shMove:SetOrder(2)
	if shMove.SetSmoothing then shMove:SetSmoothing("IN_OUT") end
	local shOut = shine:CreateAnimation("Alpha")
	shOut:SetFromAlpha(1)
	shOut:SetToAlpha(0)
	shOut:SetDuration(0.50)
	shOut:SetOrder(2)
	if shOut.SetSmoothing then shOut:SetSmoothing("IN") end
	shine.move = shMove
	shine:SetScript("OnFinished", function() R.shineFrame:SetAlpha(0) end)
	shine:SetScript("OnStop", function() R.shineFrame:SetAlpha(0) end)
	R.shineFrame.anim = shine

	-- A refusal: the text shakes its head, two pixels either way.
	local shake = R.textLayer:CreateAnimationGroup()
	for i, dx in ipairs({ -2, 4, -4, 2 }) do
		local step = shake:CreateAnimation("Translation")
		step:SetOffset(dx, 0)
		step:SetDuration(0.06)
		step:SetOrder(i)
	end
	R.textLayer.shake = shake

	-- Leaving after the last buff: the panel fades over the second half of the
	-- confirmation. The button is still hidden when the confirmation runs out;
	-- art is parked invisible until then, and the next Refresh restores the
	-- alpha.
	local outro = R.art:CreateAnimationGroup()
	local oFade = outro:CreateAnimation("Alpha")
	oFade:SetFromAlpha(1)
	oFade:SetToAlpha(0)
	oFade:SetDuration(OUTCOME_SECONDS * 0.5)
	Try(oFade, "SetStartDelay", OUTCOME_SECONDS * 0.5)
	if oFade.SetSmoothing then oFade:SetSmoothing("IN") end
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

-- Whether the extra motion is wanted: the landing burst, the shine, the shake
-- and the outro. "Calm" drops those four; everything else (the fades, the rise
-- in, the text cross-fade, the stripe sweep, the favour glow) still plays.
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
	if R.burstFrame.anim and R.burstFrame.anim:IsPlaying() then R.burstFrame.anim:Stop() end
	if R.shineFrame.anim and R.shineFrame.anim:IsPlaying() then R.shineFrame.anim:Stop() end
	if R.textLayer.shake and R.textLayer.shake:IsPlaying() then R.textLayer.shake:Stop() end
	if S.activeLook then S.activeLook:StopFlourishes() end
end

-- The band of light across the panel, brighter for a landed buff than for an
-- arrival. Not on the Minimal look: additive light with no panel under it is a
-- white column sweeping over the world.
function Prompt:PlayShine(r, g, b, strength)
	if not R.shineFrame.anim then return end
	if ns.db and ns.db.profile.prompt.style == "minimal" then return end
	Gradient(R.shineLeft, "HORIZONTAL", r, g, b, 0, r, g, b, strength)
	Gradient(R.shineRight, "HORIZONTAL", r, g, b, strength, r, g, b, 0)
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

function Prompt:StopAttention()
	if R.glowFrame.pulse and R.glowFrame.pulse:IsPlaying() then R.glowFrame.pulse:Stop() end
	R.glowFrame:SetAlpha(0)
	if S.activeLook then S.activeLook:StopAttention() end
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
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then r, g, b = self:AccentColor("owed") end
		self:PlayShine(r, g, b, 0.20)
	end

	-- The glow is drawn around the icon, so it goes with it.
	if not p.showIcon then
		self:StopAttention()
		return
	end

	if mode == "pulse" then
		if R.glowFrame.pulse and not R.glowFrame.pulse:IsPlaying() then
			if R.glowFrame.anim then R.glowFrame.anim:Stop() end
			R.glowFrame.pulse:Play()
		end
	else
		-- Unconditionally, before anything else plays: the looping pulse is
		-- only stopped in the branch above, so switching away from Pulse left
		-- it running.
		if R.glowFrame.pulse then R.glowFrame.pulse:Stop() end
		if isNew and R.glowFrame.anim then
			R.glowFrame.anim:Stop()
			R.glowFrame.anim:Play()
		end
	end
end

-- The motion for an outcome, once: ring and light for a confirmed buff, a
-- shake for a refusal, nothing for an unconfirmed cast. None when quiet in
-- combat, on "Calm", or with the panel not shown.
function Prompt:PlayOutcomeFlourish(kind)
	local p = ns.db and ns.db.profile.prompt
	if not p or not FullEffects() then return end
	if InCombatLockdown() and p.hideInCombat then return end
	if not R.button:IsShown() then return end
	self:StopFlourishes()
	if S.activeLook then
		S.activeLook:Flourish(kind)
		if kind == "failed" and R.textLayer.shake then R.textLayer.shake:Play() end
		return
	end
	if kind == "cast" then
		-- Coloured here rather than by PaintAccent: the repaint that follows
		-- is usually about the next person, and the ring belongs to this one.
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then
			r, g, b = self:AccentColor(S.current and S.current.reason or "owed")
		end
		if p.showIcon and R.burstFrame.anim then
			PaintHalo(R.burstHalo, r, g, b, 1)
			R.burstFrame.anim:Play()
		end
		self:PlayShine(1, 1, 1, 0.30)
	elseif kind == "failed" then
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
