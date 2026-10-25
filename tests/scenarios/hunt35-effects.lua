-- Hunt 35: the prompt's effects and art, raised.
--
-- Every effect here is a group on a frame the addon owns, and a broken one
-- throws nothing: an arrival that plays on every repaint, a landing that does
-- not radiate, a refusal that radiates as if it had landed, a Calm that
-- still scales, a ring left lit when the look changes, a fight in which the
-- secure button is animated. The only evidence is what the frames were told,
-- so these run on the recording CreateFrame in tests/frametree.lua, which
-- remembers every Play and Stop and which frame owned the group.
--
-- What they hold the effects to, in each of the six looks:
--   * each plays on its own event and on no other (an arrival for somebody
--     owed, once; rings for a buff the game confirmed; a contracting ring and
--     a shake for a refusal; nothing for a cast nobody confirmed);
--   * Calm plays none of the new motion, only fades;
--   * in a fight none of it is on a protected frame, and on "Keep the prompt
--     dim and still" none of it plays;
--   * all of it stops with the look, the panel and the repaint that is about
--     somebody else, and parks what it lit at nothing;
--   * each stays inside its time (an arrival under half a second, a landing
--     under 0.7 s, a refusal 0.3 s, a breath 2 to 3 s round);
--   * the art it is drawn with ships at the right size, and every texture
--     generator draws the same bytes twice and the bytes that ship.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ANNA_BERT = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }
local BUILTIN = { "glass", "framed", "minimal" }
local ALL = { "glass", "framed", "minimal", "luxe", "toast", "arcane" }

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function plays(g) return g and g._plays or 0 end
local function total(list)
	local n = 0
	for _, g in ipairs(list) do n = n + plays(g) end
	return n
end

-- The prompt in `style`, with `edit` applied first, Anna on the panel as a
-- passer-by (not owed): the moment before a favour arrives.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = style
	p.flashStyle = "pulse"
	p.effects = "full"
	p.hideInCombat = false
	p.showIcon = true
	p.roundIcon = false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	return ns.Prompt:Regions(), p
end

-- The groups each look keeps for each moment, by name, so one scenario can
-- ask every look the same question. `arrive` is what a favour arriving plays
-- (and only that), `land` what a buff that landed does, `reject` what a
-- refusal does besides the shake.
local function groupsOf(r)
	local look = r.look
	local fx = look and look.fx or r.fx
	local g = { shake = { r.shake } }
	local rings = { fx.rings[1].land, fx.rings[2].land }
	g.reject = { fx.rings[1].reject }
	g.land = { rings[1], rings[2], r.settle }
	if not look then
		g.arrive = { r.fx.echo.drop, r.burst.arrive }
		g.land[#g.land + 1] = r.burst.anim
		g.land[#g.land + 1] = r.shine.anim
		g.reject[#g.reject + 1] = r.burst.reject
		g.intro, g.introCalm = { r.intro }, { r.introCalm }
		return g
	end
	g.intro, g.introCalm = { r.intro }, { r.introCalm }
	if look.key == "luxe" then
		g.arrive = { look.lockAnim }
		g.land[#g.land + 1] = look.landAnim
		g.land[#g.land + 1] = look.sheenAnim
		g.reject[#g.reject + 1] = look.landAnim
	elseif look.key == "toast" then
		g.arrive = {}
		for _, a in ipairs(look.arrive) do g.arrive[#g.arrive + 1] = a end
		for _, a in ipairs(look.flareAnims) do
			g.land[#g.land + 1] = a
			g.reject[#g.reject + 1] = a
		end
	elseif look.key == "arcane" then
		g.arrive = { look.lockAnim, look.runeFlareAnim }
		g.land[#g.land + 1] = look.runeFlareAnim
		g.land[#g.land + 1] = look.checkAnim
	end
	return g
end

local function snapshot(g)
	return { arrive = total(g.arrive), land = total(g.land), reject = total(g.reject),
		shake = total(g.shake), ring = plays(g.land[1]), ring2 = plays(g.land[2]), refuseRing = plays(g.reject[1]),
		settle = plays(g.land[3]), intro = total(g.intro), introCalm = total(g.introCalm) }
end

-- ------------------------------------------------------------------ 1
-- A favour arriving plays the arrival once, for somebody owed, and not for a
-- passer-by, not on a repaint, and not over an outcome.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: a favour arriving plays the arrival once, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style)
		local g = groupsOf(r)
		-- Somebody on the panel who is not owed: no arrival.
		local before = snapshot(g)
		if before.arrive ~= 0 then
			fail(scenario, "a passer-by on the panel played the favour's arrival")
		end
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local after = snapshot(g)
		-- Toast shows the arrival's light for a favour just done, which this is.
		if after.arrive <= before.arrive then
			fail(scenario, "somebody buffing you did not play the arrival")
		end
		if not r.look and plays(r.fx.echo.drop) ~= 1 then
			fail(scenario, "the icon's echo played " .. plays(r.fx.echo.drop) .. " times for one favour")
		end
		-- And once: the next scans are the same person owed the same favour.
		Mock.advance(0.4)
		ns.addon:Tick()
		Mock.advance(0.4)
		ns.addon:Tick()
		if snapshot(g).arrive ~= after.arrive then
			fail(scenario, "the arrival played again on a repaint of the same favour")
		end
		-- Nothing of a refusal or a landing came with it: not the rings, not the
		-- settle, not the contracting ring, not the shake. (The light across
		-- the panel is the favour's own as well, so it is not counted.)
		local now = snapshot(g)
		if now.ring ~= before.ring or now.ring2 ~= before.ring2 or now.settle ~= before.settle
			or now.refuseRing ~= before.refuseRing or now.shake ~= before.shake then
			fail(scenario, "an arrival played the landing's or the refusal's effects")
		end
	end)
end

-- Somebody arriving while an outcome is still up does not play over it.
withTree("hunt35-effects: an arrival does not play over an outcome", ANNA_BERT, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1)
	FT.settle()
	local echo, arrive = plays(r.fx.echo.drop), plays(r.burst.arrive)
	-- Anna is dealt with and Bert buffs you in the same moment the press lands.
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	owe(ns, "Bert Beside")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(r.fx.echo.drop) ~= echo or plays(r.burst.arrive) ~= arrive then
		fail(scenario, "the arrival of the next favour played over the confirmation of the last")
	end
end)

-- ------------------------------------------------------------------ 2
-- A landed buff radiates and a refusal contracts, each only on its own event.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: a landed buff radiates and a refusal contracts, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.advance(1)
		FT.settle()
		local g = groupsOf(r)
		local s0 = snapshot(g)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		local s1 = snapshot(g)
		if s1.ring <= s0.ring or s1.ring2 <= s0.ring2 then
			fail(scenario, "a buff the game confirmed did not spread both rings from the icon")
		end
		if s1.settle <= s0.settle then fail(scenario, "a landed buff did not settle the panel") end
		if s1.land - s0.land < 3 then fail(scenario, "a landed buff played fewer of its effects than it has") end
		if s1.shake ~= s0.shake or s1.refuseRing ~= s0.refuseRing then
			fail(scenario, "a landed buff shook the text or contracted a ring as a refusal does")
		end
		Mock.advance(1)
		FT.settle()
		local s2 = snapshot(g)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		local s3 = snapshot(g)
		if s3.refuseRing <= s2.refuseRing then fail(scenario, "a refusal did not contract a ring onto the icon") end
		if s3.shake <= s2.shake then fail(scenario, "a refusal did not shake the text") end
		if s3.ring ~= s2.ring or s3.ring2 ~= s2.ring2 or s3.settle ~= s2.settle then
			fail(scenario, "a refusal spread the landing's rings or settled the panel as if it had landed")
		end
		Mock.advance(1)
		FT.settle()
		local s4 = snapshot(g)
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		local s5 = snapshot(g)
		if s5.land ~= s4.land or s5.reject ~= s4.reject or s5.shake ~= s4.shake then
			fail(scenario, "a cast nobody confirmed got a flourish, which claims more than the settle path knows")
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- Calm is fades only: no echo, no rings, no scale, no light across, no shake.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: Calm plays none of the new motion, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style, p.effects, p.flashStyle, p.hideInCombat = style, "calm", "pulse", false
		p.showIcon, p.roundIcon = true, false
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		FT.settle()
		local r = ns.Prompt:Regions()
		local g = groupsOf(r)
		local s0 = snapshot(g)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.advance(1)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		Mock.advance(1)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		Mock.advance(1)
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		local s1 = snapshot(g)
		for _, key in ipairs({ "arrive", "land", "reject", "shake", "settle", "intro" }) do
			if s1[key] ~= s0[key] then
				fail(scenario, "with Effects on Calm the " .. key .. " still played")
			end
		end
		-- The entrance a Calm panel gets is a fade and nothing else.
		for _, a in ipairs(r.introCalm._anims) do
			if a._kind ~= "Alpha" then
				fail(scenario, "Calm's entrance has a " .. tostring(a._kind) .. " in it, not only a fade")
			end
		end
		if #r.introCalm._anims == 0 then fail(scenario, "Calm's entrance is empty") end
	end)
end

-- The panel coming up plays the entrance that fits the setting.
for _, effects in ipairs({ "full", "calm" }) do
	local name = "hunt35-effects: the panel comes up with the entrance " .. effects .. " asks for"
	withTree(name, ANNA, function(ns, scenario)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style, p.effects = "glass", effects
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		-- Down, so the next scan brings it up.
		ns.Prompt:GetButton():Hide()
		local full, calm = plays(r.intro), plays(r.introCalm)
		ns.addon:Tick()
		if not ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the panel did not come up")
			return
		end
		local wantFull = effects == "full"
		if (plays(r.intro) > full) ~= wantFull or (plays(r.introCalm) > calm) == wantFull then
			fail(scenario, "on " .. effects .. " the panel came up with the wrong entrance")
		end
	end)
end

-- ------------------------------------------------------------------ 4
-- In a fight none of it is on a protected frame, and on "dim and still" none
-- of it plays.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: in a fight no effect touches a protected frame, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		for _, row in ipairs(r.rowButtons or {}) do Mock.protect(row) end
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		ns.addon:Tick()
		FT.settle()
		Mock.protectedCalls = {}
		local g = groupsOf(r)
		local s0 = snapshot(g)
		Mock.advance(1)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		Mock.advance(1)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		if #Mock.protectedCalls > 0 then
			fail(scenario, "an outcome's effects in a fight called " .. table.concat(Mock.protectedCalls, ", ")
				.. " on the secure frame")
		end
		local s1 = snapshot(g)
		if s1.shake <= s0.shake then
			fail(scenario, "SKIPPED -- the refusal did not play in the fight, so there is nothing to judge")
		end
		for _, group in ipairs(FT.groups()) do
			local o = group._owner
			if o == button or (o and o._protected) then
				fail(scenario, "an animation group is on a protected frame")
				break
			end
		end
		-- "Keep the prompt dim and still": none of it plays.
		ns.db.profile.prompt.hideInCombat = true
		Mock.advance(1)
		local s2 = snapshot(g)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		Mock.advance(1)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		local s3 = snapshot(g)
		for _, key in ipairs({ "land", "reject", "shake", "settle" }) do
			if s3[key] ~= s2[key] then
				fail(scenario, "with the prompt kept dim and still in combat the " .. key .. " still played")
			end
		end
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	end)
end

-- ------------------------------------------------------------------ 5
-- Everything stops: a repaint about somebody else, another look. The rings
-- and the light are not left playing on a frame that is gone.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: every effect stops cleanly on a repaint and a restyle, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.advance(1)
		FT.settle()
		local g = groupsOf(r)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		local function playingIn(lists, skip)
			for _, list in ipairs(lists) do
				for i, group in ipairs(list) do
					if group._playing and not (skip and skip[group]) then return true end
				end
			end
			return false
		end
		if not playingIn({ g.land }) then
			fail(scenario, "SKIPPED -- nothing played for the landing")
			return
		end
		-- A repaint about somebody else.
		ns.Prompt:StopFlourishes()
		if playingIn({ g.land, g.reject, g.shake }) then
			fail(scenario, "a landing's or a refusal's effect was still playing after a repaint stopped them")
		end
		-- Another look: what the first drew is gone. The panel's settle is
		-- the art's own and runs on whatever look is up.
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		-- (From one of the three built-in looks to another the frames are the
		-- same and stay up, so those go to a look of its own.)
		local builtin = style == "glass" or style == "framed" or style == "minimal"
		ns.db.profile.prompt.style = builtin and "luxe" or "glass"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		if playingIn({ g.land, g.reject }, { [r.settle] = true }) then
			fail(scenario, "an effect of the old look was still playing after the look changed")
		end
	end)
end

withTree("hunt35-effects: the breath stops with the favour and with the panel", ANNA, function(ns, scenario)
	for _, style in ipairs(ALL) do
		local r = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		-- Long enough for an arrival's flare to give way to the breath.
		Mock.advance(1.5)
		FT.settle()
		local _, loops = FT.playing()
		if #loops == 0 then fail(scenario, style .. ": nothing breathes with somebody owed on top") end
		wipe(ns.owed)
		ns.addon:Tick()
		FT.settle()
		_, loops = FT.playing()
		if #loops > 0 then fail(scenario, style .. ": " .. #loops .. " loop(s) kept going with nobody owed") end
		if r.rim and (r.rim._alpha or 0) > 0.001 then fail(scenario, style .. ": the rim was left lit") end
	end
end)

-- ------------------------------------------------------------------ 6
-- The refusal's shake dies away and sums to nothing.
withTree("hunt35-effects: the refusal's shake dies away and ends where it began", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local steps, sum, last = {}, 0, nil
	for _, a in ipairs(r.shake._anims) do
		steps[#steps + 1] = { order = a._order, dx = a._offset and a._offset[1] or 0, d = a._duration }
	end
	table.sort(steps, function(a, b) return a.order < b.order end)
	if #steps < 5 then fail(scenario, "the shake has only " .. #steps .. " steps") return end
	for _, s in ipairs(steps) do sum = sum + s.dx end
	if sum ~= 0 then fail(scenario, "the shake's steps add up to " .. sum .. ", so the text ends displaced") end
	local peak, peakAt = 0, 1
	for i, s in ipairs(steps) do
		if math.abs(s.dx) > peak then peak, peakAt = math.abs(s.dx), i end
	end
	for i = peakAt + 1, #steps do
		if math.abs(steps[i].dx) > math.abs(steps[i - 1].dx) then
			fail(scenario, "the shake grows again after its peak, so it does not die away")
		end
	end
	last = math.abs(steps[#steps].dx)
	if last >= peak / 2 then fail(scenario, "the shake ends nearly as hard as it began") end
	if FT.groupLength(r.shake) > 0.35 then
		fail(scenario, ("the shake lasts %.2f s, over its 0.35"):format(FT.groupLength(r.shake)))
	end
end)

-- ------------------------------------------------------------------ 7
-- Timings: an arrival under half a second, a landing under 0.7, a refusal
-- 0.3, a breath two to three seconds round.
withTree("hunt35-effects: the effects stay inside their times", ANNA, function(ns, scenario)
	for _, style in ipairs(ALL) do
		local r = upIn(ns, scenario, style)
		local g = groupsOf(r)
		local function within(list, limit, what)
			for _, group in ipairs(list) do
				if group and FT.groupLength(group) > limit then
					fail(scenario, ("%s: %s lasts %.2f s, over %.2f"):format(style, what,
						FT.groupLength(group), limit))
				end
			end
		end
		within(g.arrive, 0.7, "an arrival's effect")
		within(g.land, 0.7, "a landing's effect")
		within({ g.reject[1] }, 0.35, "a refusal's ring")
		within(g.reject, 0.5, "a refusal's effect")
		if style == "glass" or style == "framed" or style == "minimal" then
			within({ r.fx.echo.drop, r.burst.arrive, r.intro }, 0.5, "the arrival")
			within(g.land, 0.7, "a landing")
		end
		-- The breath, round.
		local breath
		if not r.look then
			breath = r.glow.pulse and r.glow.pulse._anims[1]._duration
			local rim = r.rim.pulse and r.rim.pulse._anims[1]._duration
			if breath ~= rim then fail(scenario, style .. ": the glow and the rim breathe at different rates") end
		elseif r.look.key == "luxe" or r.look.key == "arcane" then
			breath = r.look.pulseAnim._anims[1]._duration
		else
			breath = r.look.pulse[1]._anims[1]._duration
		end
		if not breath or breath * 2 < 2 or breath * 2 > 3 then
			fail(scenario, ("%s: the owed breath is %.2f s round, not 2 to 3"):format(style, (breath or 0) * 2))
		end
	end
end)

-- ------------------------------------------------------------------ 8
-- The owed breath is two tones: the reason's light and a warm white rim, on
-- the same breath.
withTree("hunt35-effects: the owed breath is the reason's colour and a warm white rim", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(0.5)
	if not (r.glow.pulse._playing and r.rim.pulse._playing) then
		fail(scenario, "somebody owed on top and the glow and the rim are not both breathing")
	end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local strip, rim = r.glowStrips and r.glowStrips[1], r.rimStrips and r.rimStrips[1]
	if not (strip and strip._color and strip._color[1] == cr and strip._color[2] == cg) then
		fail(scenario, "the glow is not in the reason's colour")
	end
	local w = ns.Prompt.lib.WARM_WHITE
	if not (rim and rim._color and rim._color[1] == w[1] and rim._color[3] == w[3]) then
		fail(scenario, "the rim is not the warm white")
	end
	if rim._color[3] >= rim._color[1] then fail(scenario, "the warm white is not warm: blue is not under red") end
	-- The other three look keep a warm ring over the same breath.
	for _, style in ipairs({ "luxe", "toast", "arcane" }) do
		local rr = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.advance(0.5)
		local look = rr.look
		local warm = look.pulseRing or look.ringWarm or look.warmRing
		if not warm then
			fail(scenario, style .. " has no warm ring on its owed breath")
		else
			local c = warm._color
			if not (c and c[1] > c[3]) then fail(scenario, style .. "'s second tone is not warm") end
		end
	end
end)

-- ------------------------------------------------------------------ 9
-- The cooldown sweep draws its leading edge, round where the icon is.
for _, style in ipairs(ALL) do
	local name = "hunt35-effects: the cooldown sweep has a leading edge, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r, p = upIn(ns, scenario, style, function(pp) pp.roundIcon = true end)
		owe(ns, "Anna Aim")
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
		ns.Prompt:SyncCooldown()
		local cd = r.cooldown
		if not cd then fail(scenario, "SKIPPED -- no cooldown frame") return end
		if cd._drawEdge ~= true then fail(scenario, "the sweep has no leading edge") end
		if not cd._cooldown then fail(scenario, "SKIPPED -- the sweep is not running") end
		if cd._circular ~= true then fail(scenario, "the sweep's edge is not round with a round icon") end
		p.roundIcon = false
		ns.Prompt:ApplyStyle()
		-- Toast's medallion is round whatever the setting says.
		local want = style == "toast"
		if cd._circular ~= want then
			fail(scenario, "the sweep's edge stayed round after the icon was squared: " .. tostring(cd._circular))
		end
	end)
end

-- ------------------------------------------------------------------ 10
-- The glass has its bevel and its reflection, and the other two built-in
-- looks do not.
withTree("hunt35-effects: the glass has a bevel and a reflection, the others do not", ANNA, function(ns, scenario)
	for _, style in ipairs(BUILTIN) do
		local r = upIn(ns, scenario, style)
		local shown = FT.visible(r.bevel[1]) and FT.visible(r.bevel[5])
		if (style == "glass") ~= shown then
			fail(scenario, style .. ": the bevel is " .. (shown and "shown" or "hidden") .. " when it should not be")
		end
		if not tostring(r.sheen._file):find("Gloss", 1, true) then
			fail(scenario, style .. ": the glass's sheen is not the reflection art")
		end
	end
	local r = upIn(ns, scenario, "glass")
	if #r.bevel ~= 9 then fail(scenario, "the bevel is not nine slices") end
	-- Scaled by the panel's own opacity, so a nearly clear panel keeps no bevel.
	local before = r.bevel[2]._color and r.bevel[2]._color[4]
	ns.db.profile.prompt.bgColor = { 0.04, 0.04, 0.06, 0.2 }
	ns.Prompt:ApplyStyle()
	local after = r.bevel[2]._color and r.bevel[2]._color[4]
	if not (before and after and after < before) then
		fail(scenario, "the bevel does not follow the panel's opacity")
	end
end)

-- ------------------------------------------------------------------ 11
-- The tints worked out from the reason colours stay inside the colour, and
-- the palettes are untouched by them.
withTree("hunt35-effects: derived tints stay in range and leave the palettes alone", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local lib = ns.Prompt.lib
	local Tint = lib.Tint
	for _, palette in ipairs({ "standard", "colourblind" }) do
		ns.db.profile.prompt.reasonPalette = palette
		for _, reason in ipairs({ "target", "owed", "group", "nearby", "asked", "self" }) do
			local c = lib.ReasonColor(reason)
			local r0, g0, b0 = c[1], c[2], c[3]
			for _, t in ipairs({ -1, -0.5, 0, 0.25, 0.5, 1 }) do
				local r, g, b = Tint(r0, g0, b0, t)
				if r < 0 or g < 0 or b < 0 or r > 1 or g > 1 or b > 1 then
					fail(scenario, ("%s/%s tinted by %.2f leaves the range"):format(palette, reason, t))
				end
			end
			local r, g, b = Tint(r0, g0, b0, 0)
			if r ~= r0 or g ~= g0 or b ~= b0 then fail(scenario, "a tint of nothing changed the colour") end
			r, g, b = Tint(r0, g0, b0, 1)
			if r ~= 1 or g ~= 1 or b ~= 1 then fail(scenario, "a full tint is not white") end
			r, g, b = Tint(r0, g0, b0, -1)
			if r ~= 0 or g ~= 0 or b ~= 0 then fail(scenario, "a full shade is not black") end
			local lr = Tint(r0, g0, b0, 0.3)
			if lr < r0 then fail(scenario, "a tint darkened a colour") end
			-- The palette itself is what ReasonColor says again.
			local again = lib.ReasonColor(reason)
			if again[1] ~= r0 or again[2] ~= g0 or again[3] ~= b0 then
				fail(scenario, "the reason colour changed under a tint")
			end
		end
	end
	local known = {
		standard = { target = { 0.62, 0.90, 1.00 }, owed = { 1.00, 0.78, 0.30 }, group = { 0.34, 0.60, 0.96 },
			nearby = { 0.52, 0.54, 0.62 }, asked = { 0.96, 0.52, 0.80 } },
		colourblind = { target = { 0.98, 0.96, 0.56 }, owed = { 0.92, 0.48, 0.08 }, group = { 0.42, 0.78, 1.00 },
			nearby = { 0.80, 0.20, 1.00 }, asked = { 0.72, 0.20, 0.34 } },
	}
	for palette, set in pairs(known) do
		ns.db.profile.prompt.reasonPalette = palette
		for reason, want in pairs(set) do
			local c = lib.ReasonColor(reason)
			if c[1] ~= want[1] or c[2] ~= want[2] or c[3] ~= want[3] then
				fail(scenario, ("the %s %s colour is not what it was"):format(palette, reason))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 12
-- The art ships: 32-bit uncompressed TGAs, power-of-two sides, none past 256.
local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { idLength = b[1], mapType = b[2], imageType = b[3], width = b[13] + b[14] * 256,
		height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n % 2 == 0 do n = n / 2 end
	return n == 1
end

withTree("hunt35-effects: the new art ships at the right size", ANNA, function(ns, scenario)
	local files = {
		"Textures/Glow", "Textures/GlowRound", "Textures/Ring", "Textures/RingSq", "Textures/Sweep",
		"Textures/Gloss", "Textures/Bevel", "Textures/Luxe/Luxe_Spine", "Textures/Toast/Toast_MedShade",
	}
	for _, name in ipairs(files) do
		local h = header(dir .. "/" .. name .. ".tga")
		if not h then
			fail(scenario, name .. ".tga is not in the package")
		else
			if h.imageType ~= 2 or h.bits ~= 32 then
				fail(scenario, name .. ".tga is not a 32-bit uncompressed TGA")
			end
			if not (powerOfTwo(h.width) and powerOfTwo(h.height)) or h.width > 256 or h.height > 256 then
				fail(scenario, ("%s.tga is %dx%d, not a power of two up to 256"):format(name, h.width, h.height))
			end
		end
	end
	-- Every file the prompt draws its own light from is named in the code that
	-- draws it, so none is left shipping unused.
	local source = assert(io.open(dir .. "/Prompt/Prompt.lua", "r")):read("*a")
	for _, name in ipairs({ "Ring", "RingSq", "Sweep", "Gloss", "Bevel", "Glow", "GlowRound" }) do
		if not source:find("Textures\\\\" .. name .. '"', 1, true) then
			fail(scenario, "Textures/" .. name .. ".tga is not drawn by Prompt/Prompt.lua")
		end
	end
end)

-- ------------------------------------------------------------------ 13
-- Each texture generator draws the same bytes twice, and the bytes that ship.
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- A directory name nobody else is using: scenarios run in parallel, each in
-- a copy of the tree of its own, and a name made from the clock and a random
-- number is the same in every one of them (Lua 5.1 starts math.random at the
-- same place), so two generators wrote, compared and removed each other's
-- files. The tree's own path is different in every copy.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

local GENERATORS = {
	{ "tools/make-glow.py", "Textures" },
	{ "tools/make_luxe_textures.py", "Textures/Luxe" },
	{ "tools/make_toast_textures.py", "Textures/Toast" },
	{ "tools/make_arcane_textures.py", "Textures/Arcane" },
}

local python = os.getenv("MANNERS_PYTHON") or "python"

for _, gen in ipairs(GENERATORS) do
	local script, shipped = gen[1], gen[2]
	local name = "hunt35-effects: " .. script:match("[^/]+$") .. " is deterministic and draws what ships"
	withTree(name, ANNA, function(_, scenario)
		local a, b = tempDir() .. "-a", tempDir() .. "-b"
		local function run(out)
			local f = io.popen(python .. ' "' .. dir .. "/" .. script .. '" --out "' .. out .. '" 2>&1')
			if not f then return nil end
			local text = f:read("*a")
			f:close()
			return text
		end
		local outA, outB = run(a), run(b)
		if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
		local names = {}
		for file in outA:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
		if #names == 0 then fail(scenario, "the generator wrote nothing: " .. outA:sub(1, 200)) return end
		for _, file in ipairs(names) do
			local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
			local ships = slurp(dir .. "/" .. shipped .. "/" .. file)
			-- Never past 256 on a side, always a power of two, 32-bit.
			local h = header(a .. "/" .. file)
			if h and (h.width > 256 or h.height > 256 or not powerOfTwo(h.width) or not powerOfTwo(h.height)
				or h.bits ~= 32 or h.imageType ~= 2) then
				fail(scenario, ("%s is %dx%d at %d bits, type %d"):format(file, h.width, h.height, h.bits, h.imageType))
			end
			if not one or not two then
				fail(scenario, file .. " was not written")
			elseif one ~= two then
				fail(scenario, file .. " differs between two runs with the same parameters")
			elseif not ships then
				fail(scenario, file .. " is drawn but does not ship")
			elseif one ~= ships then
				fail(scenario, file .. " does not match the file that ships: run the generator")
			end
			os.remove(a .. "/" .. file)
			os.remove(b .. "/" .. file)
		end
	end)
end
