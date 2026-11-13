-- landing-light: what a buff landing and a refusal do to the two looks drawn
-- here (glass, minimal) beyond the rings: the material answering.
--
-- A landing lights the panel's edge in the reason's colour -- the material
-- itself, a copy of the glass's cut-edge light
-- drawn as light (the two rules on Minimal, which has no edge) -- sends a
-- wave of the same light from the icon's
-- right edge across the panel at the old shine's strength, swells the panel a
-- little, and washes it in colour that fades rather than cuts. A refusal
-- breaks the ward: the edge flashes red, the ground cracks along the bottom
-- band under the words, the top rule sputters, the icon greys for the outcome
-- and the words take a struck seven-step shake (Prompt/Effects.lua,
-- PlayOutcomeFlourish and BuildAnimations; Prompt/Paint.lua, PaintOutcome;
-- Prompt/Panel.lua places the frames).
--
-- What it holds: the edge's light never over 0.40; the wave from the icon's
-- edge at strength 0.30; the wash played once per outcome and resting where
-- it fell; the wash's frame under every frame of light; the crack under the
-- words and inside the bottom eight units at every size; the icon given its
-- colour back at every clear, for a flag's cost on the scans between; every
-- group parked and stopped with the look; Calm and a quiet fight playing none
-- of it; the old band's file gone.
--
-- The evidence is the frame tree's (tests/frametree.lua).

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local T = "landing-light: "
local ANNA = { nameplate1 = { "Anna", "Aim" } }

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
local function near(a, b, eps) return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-6) end

-- The prompt in `style` on Full, `edit` applied first, Anna owed and on the
-- panel, every arrival flourish over and parked: the moment before a press.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.flashStyle, p.effects, p.hideInCombat = style, "pulse", "full", false
	p.showIcon, p.roundIcon, p.showSub = true, false, true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1.5)
	FT.settle()
	return ns.Prompt:Regions(), p
end

-- The highest alpha a group's fades reach.
local function peakOf(g)
	local peak = 0
	for _, a in ipairs(g._anims) do
		if a._kind == "Alpha" then peak = math.max(peak, a._toAlpha or 0, a._fromAlpha or 0) end
	end
	return peak
end

-- The groups this file is about, by name.
local function newGroups(r)
	return {
		edgeLand = r.edgeLight.land, edgeReject = r.edgeLight.reject,
		flare1 = r.rules[1].flare, flare2 = r.rules[2].flare, flicker = r.rules[1].flicker,
		split = r.crack.split, fade = r.wash.fade, shine = r.shine.anim,
	}
end

local function counts(groups)
	local out = {}
	for name, g in pairs(groups) do out[name] = plays(g) end
	return out
end

-- ------------------------------------------------------------------ 1
-- A landing on glass lights the edge: once, in the reason's colour taken over
-- half-way to white, never over 0.40, for half a second, and parked after.
withTree(T .. "the edge light stays under 0.40", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local edge = r.edgeLight
	if not (edge and edge.land and edge.pieces and #edge.pieces == 9) then
		fail(scenario, "SKIPPED -- the edge's light is not reachable")
		return
	end
	if not FT.visible(edge) then fail(scenario, "the edge's frame is hidden on glass") end
	if (edge._alpha or 0) > 0.001 then fail(scenario, "the edge is lit before anything landed") end
	local before = plays(edge.land)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(edge.land) ~= before + 1 then
		fail(scenario, ("the edge lit %d times for one landing"):format(plays(edge.land) - before))
	end
	if plays(edge.reject) ~= 0 then fail(scenario, "a landing flashed the edge red") end
	local peak = peakOf(edge.land)
	if peak > 0.40 + 1e-6 then fail(scenario, ("the edge's light peaks at %.2f, over 0.40"):format(peak)) end
	if peak < 0.39 then fail(scenario, ("the edge's light peaks at %.2f, too faint to be seen"):format(peak)) end
	if not near(FT.groupLength(edge.land), 0.50, 0.001) then
		fail(scenario, ("the edge's light lasts %.2f s, not 0.50"):format(FT.groupLength(edge.land)))
	end
	for _, a in ipairs(edge.land._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "the edge's light moves: " .. tostring(a._kind)) end
	end
	-- The colour: the reason's, taken 0.55 of the way to white, on every
	-- piece of the edge, and the pieces are light (additive).
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local er, eg, eb = ns.Prompt.lib.Tint(cr, cg, cb, 0.55)
	for i, piece in ipairs(edge.pieces) do
		local c = piece._color
		if not (c and near(c[1], er, 0.001) and near(c[2], eg, 0.001) and near(c[3], eb, 0.001)) then
			fail(scenario, ("edge piece %d is not the reason's colour taken over half-way to white"):format(i))
		end
		if piece._blend ~= "ADD" then fail(scenario, ("edge piece %d is not drawn as light"):format(i)) end
	end
	-- Under the text, and parked once the half-second is over.
	if (edge._level or 0) >= (r.textLayer._level or 0) then fail(scenario, "the edge's light is over the text") end
	Mock.advance(0.6)
	FT.settle()
	if edge.land._playing then fail(scenario, "the edge's light is still playing 0.6 s in") end
	if (edge._alpha or 0) > 0.001 then fail(scenario, "the edge was left lit after its light") end
end)

-- ------------------------------------------------------------------ 2
-- The wave bursts from the icon's right edge, about a fifth of the panel wide
-- and as tall as it, runs to two units short of the panel's end, at the shine's
-- old strength 0.30 and never full under the words; the panel's settle swells
-- to 1.035 and back in 0.36 s.
withTree(T .. "the shockwave keeps the shine's strength", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "glass")
	local shine = r.shine and r.shine.anim
	if not (shine and r.shineBand) then fail(scenario, "SKIPPED -- the wave is not reachable") return end
	if not tostring(r.shineBand._file):find("Textures\\Shock", 1, true) then
		fail(scenario, "the wave is not drawn from Textures/Shock.tga: " .. tostring(r.shineBand._file))
	end
	if r.shineBand._blend ~= "ADD" then fail(scenario, "the wave is not light") end
	-- Where it starts and how far it runs: from the icon's right edge plus two,
	-- 48 wide at the default 220, to two units short of the right edge.
	local iconL, iconR = FT.span(r.icon, "x")
	local shineL, shineR = FT.span(r.shine, "x")
	local artL, artR = FT.span(r.art, "x")
	local sb, st = FT.span(r.shine, "y")
	local pb, pt = FT.span(r.art, "y")
	if not (iconR and shineL and near(shineL, iconR + 2, 0.01)) then
		fail(scenario, ("the wave starts at %s, not two units right of the icon's edge %s"):format(tostring(shineL), tostring(iconR)))
	end
	local wantWidth = math.max(20, math.min(64, math.floor(p.width * 0.22)))
	if not (shineR and near(shineR - shineL, wantWidth, 0.01)) then
		fail(scenario, ("the wave is %s wide, not %d"):format(tostring(shineR and shineR - shineL), wantWidth))
	end
	if not (sb and near(st - sb, p.height, 0.01) and near(sb, pb, 0.01)) then
		fail(scenario, "the wave is not the panel's full height")
	end
	local off = shine.move and shine.move._offset
	local wantRun = p.width - (iconR - artL + 2) - wantWidth - 2
	if not (off and near(off[1], wantRun, 0.01) and near(off[2], 0)) then
		fail(scenario, ("the wave runs %s units, not the %d to the panel's end"):format(tostring(off and off[1]), wantRun))
	end
	if not near(FT.groupLength(shine), 0.34, 0.001) then
		fail(scenario, ("the wave takes %.2f s, not 0.34"):format(FT.groupLength(shine)))
	end
	-- Played once by the landing, at strength 0.30.
	local before = plays(shine)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(shine) ~= before + 1 then fail(scenario, ("the wave ran %d times for one landing"):format(plays(shine) - before)) end
	local c = r.shineBand._color
	if not (c and near(c[4], 0.30, 0.001)) then
		fail(scenario, ("the wave runs at strength %s, not the shine's 0.30"):format(tostring(c and c[4])))
	end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local er, eg, eb = ns.Prompt.lib.Tint(cr, cg, cb, 0.55)
	if not (near(c[1], er, 0.001) and near(c[2], eg, 0.001) and near(c[3], eb, 0.001)) then
		fail(scenario, "the wave is not the reason's colour taken over half-way to white")
	end
	-- The settle: a swell to 1.035 after a beat, and back, 0.36 s in all.
	local settle = r.settle
	local swell
	for _, a in ipairs(settle._anims) do
		if a._kind == "Scale" and a._scaleTo and a._scaleTo[1] > 1 then swell = a._scaleTo[1] end
	end
	if not near(swell, 1.035, 0.0001) then fail(scenario, ("the settle swells to %s, not 1.035"):format(tostring(swell))) end
	if not near(FT.groupLength(settle), 0.36, 0.001) then
		fail(scenario, ("the settle takes %.2f s, not 0.36"):format(FT.groupLength(settle)))
	end
	-- Parked at the end.
	Mock.advance(0.5)
	FT.settle()
	if (r.shine._alpha or 0) > 0.001 then fail(scenario, "the wave was left lit after its run") end
end)

-- ------------------------------------------------------------------ 3
-- The wash rises and falls once per outcome: a repaint of the same outcome
-- touches neither its alpha nor its colour; it rests where it fell until the
-- expiry hides it; each outcome has its own peak and rest; a second outcome
-- in the same instant gets its own.
withTree(T .. "the wash fades once", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local fade = r.wash and r.wash.fade
	if not (fade and r.fill) then fail(scenario, "SKIPPED -- the wash is not reachable") return end
	if plays(fade) ~= 0 then fail(scenario, "the wash faded before any outcome") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(fade) ~= 1 then fail(scenario, ("the wash faded %d times for one landing"):format(plays(fade))) end
	if not FT.visible(r.fill) then fail(scenario, "the wash is not shown for the landing") end
	local c = r.fill._color
	if not (c and near(c[4], 1, 0.001)) then
		fail(scenario, ("the wash's texture is at alpha %s on Full; the fade is the frame's"):format(tostring(c and c[4])))
	end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not (near(c[1], cr, 0.001) and near(c[2], cg, 0.001) and near(c[3], cb, 0.001)) then
		fail(scenario, "the landing's wash is not the reason's colour")
	end
	if not near(FT.groupLength(fade), 0.56, 0.001) then
		fail(scenario, ("the wash takes %.2f s, not 0.56"):format(FT.groupLength(fade)))
	end
	if not (fade.rise and near(fade.rise._toAlpha, 0.28, 0.001)) then
		fail(scenario, ("the landing's wash peaks at %s, not 0.28"):format(tostring(fade.rise and fade.rise._toAlpha)))
	end
	if not (fade.fall and near(fade.fall._toAlpha, 0.10, 0.001)) then
		fail(scenario, ("the landing's wash rests at %s, not 0.10"):format(tostring(fade.fall and fade.fall._toAlpha)))
	end
	for _, a in ipairs(fade._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "the wash moves: " .. tostring(a._kind)) end
	end
	-- A repaint of the same outcome: nothing restarted, nothing recoloured.
	Mock.advance(0.2)
	ns.addon:Tick()
	if plays(fade) ~= 1 then fail(scenario, "a repaint of the same outcome restarted the wash") end
	if not (r.fill._color and near(r.fill._color[4], 1, 0.001)) then fail(scenario, "a repaint of the same outcome recoloured the wash") end
	-- Run out: at rest, still shown; then hidden by the expiry.
	Mock.advance(0.4)
	FT.settle()
	if fade._playing then fail(scenario, "the wash is still fading 0.6 s in") end
	if not near(r.wash._alpha, 0.10, 0.001) then
		fail(scenario, ("the wash rests at alpha %s once it has fallen, not 0.10"):format(tostring(r.wash._alpha)))
	end
	if not FT.visible(r.fill) then fail(scenario, "the wash was hidden before the outcome ran out") end
	Mock.advance(0.1)
	ns.addon:Tick()
	if FT.visible(r.fill) then fail(scenario, "the wash is still shown after the outcome ran out") end
	-- A refusal and a cast nobody confirmed each have their own peak and rest.
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(fade) ~= 2 then fail(scenario, "a refusal did not fade the wash") end
	if not (near(fade.rise._toAlpha, 0.30, 0.001) and near(fade.fall._toAlpha, 0.12, 0.001)) then
		fail(scenario, ("a refusal's wash goes %s -> %s, not 0.30 -> 0.12"):format(tostring(fade.rise._toAlpha), tostring(fade.fall._toAlpha)))
	end
	local fr = r.fill._color
	if not (fr and near(fr[1], 0.90, 0.001) and near(fr[2], 0.26, 0.001) and near(fr[3], 0.22, 0.001)) then
		fail(scenario, "a refusal's wash is not the refusal's red")
	end
	-- Another outcome in the same instant: its own wash, its own colour.
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(fade) ~= 3 then fail(scenario, "an outcome in the same instant as the last got no wash of its own") end
	if not (near(fade.rise._toAlpha, 0.18, 0.001) and near(fade.fall._toAlpha, 0.08, 0.001)) then
		fail(scenario, ("an unconfirmed cast's wash goes %s -> %s, not 0.18 -> 0.08"):format(tostring(fade.rise._toAlpha), tostring(fade.fall._toAlpha)))
	end
	local sc = r.fill._color
	if not (sc and near(sc[1], cr, 0.001) and near(sc[2], cg, 0.001)) then fail(scenario, "an unconfirmed cast's wash kept the refusal's red") end
	-- And 'sent' plays nothing else: no wave, no edge, no crack.
	local g = newGroups(r)
	if g.shine._playing or g.edgeLand._playing or g.edgeReject._playing or g.split._playing or g.flicker._playing then
		fail(scenario, "a cast nobody confirmed played a landing's or a refusal's light")
	end
end)

-- ------------------------------------------------------------------ 4
-- The wash's frame is a level above the art like every frame of light, and
-- was made before all of them, so it draws under them; and every frame this
-- file adds is under the text's.
withTree(T .. "the wash lies under the light", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local art, wash = r.art, r.wash
	if not (art and wash and r.fill) then fail(scenario, "SKIPPED -- the wash's frame is not reachable") return end
	if (wash._level or 0) ~= (art._level or 0) + 1 then
		fail(scenario, ("the wash's frame is at level %d, the art at %d: it should be one above"):format(wash._level or 0, art._level or 0))
	end
	if r.fill._parent ~= wash then fail(scenario, "the wash's texture is not on the wash's frame") end
	-- First among the art's child frames: the lowest serial.
	local first
	for _, child in ipairs(art._children or {}) do
		if child._kind ~= "Texture" and child._kind ~= "FontString" and child._kind ~= "MaskTexture" then
			if not first or (child._serial or 0) < (first._serial or 0) then first = child end
		end
	end
	if first ~= wash then
		fail(scenario, ("the wash's frame was not made first among the art's child frames (%s was), so it draws over light made before it"):format(
			tostring(first and first._kind)))
	end
	local textLevel = r.textLayer._level or 0
	for _, item in ipairs({ { "the wash", wash }, { "the edge's light", r.edgeLight }, { "the crack", r.crack },
		{ "the wave", r.shine } }) do
		if (item[2]._level or 0) >= textLevel then
			fail(scenario, ("%s is at level %d, not under the text's %d"):format(item[1], item[2]._level or 0, textLevel))
		end
	end
end)

-- ------------------------------------------------------------------ 5
-- The edge's carrier follows the look: shown on glass, hidden on
-- Minimal, where a landing lights the two rules instead at their half strength
-- and no wave crosses (there is no panel for it).
withTree(T .. "the edge carrier follows the look", ANNA, function(ns, scenario)
	-- The frames (and their counts) live on through every restyle, so each
	-- look is judged by what one landing adds.
	for _, style in ipairs({ "glass" }) do
		local r = upIn(ns, scenario, style)
		if not FT.visible(r.edgeLight) then fail(scenario, style .. ": the edge's light is hidden") end
		local before = { plays(r.rules[1].flare), plays(r.rules[2].flare), edge = plays(r.edgeLight.land) }
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		if plays(r.edgeLight.land) ~= before.edge + 1 then fail(scenario, style .. ": a landing did not light the edge") end
		if plays(r.rules[1].flare) ~= before[1] or plays(r.rules[2].flare) ~= before[2] then
			fail(scenario, style .. ": a landing flared the rules, which are Minimal's answer")
		end
		Mock.advance(1)
		FT.settle()
	end
	local r = upIn(ns, scenario, "minimal")
	if FT.visible(r.edgeLight) then fail(scenario, "minimal shows the edge's light, and has no edge") end
	local shone, lit = plays(r.shine.anim), plays(r.edgeLight.land)
	local flared = { plays(r.rules[1].flare), plays(r.rules[2].flare) }
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(r.edgeLight.land) ~= lit then fail(scenario, "minimal lit an edge it does not have") end
	if plays(r.shine.anim) ~= shone then fail(scenario, "a wave crossed a Minimal prompt, which has no panel under it") end
	for i, rule in ipairs(r.rules) do
		if plays(rule.flare) ~= flared[i] + 1 then
			fail(scenario, ("minimal flared rule %d %d times for one landing"):format(i, plays(rule.flare) - flared[i]))
		end
		if not near(FT.groupLength(rule.flare), 0.45, 0.001) then
			fail(scenario, ("rule %d's flare lasts %.2f s, not 0.45"):format(i, FT.groupLength(rule.flare)))
		end
		if peakOf(rule.flare) > 0.55 + 1e-6 then fail(scenario, ("rule %d flares to %.2f, over 0.55"):format(i, peakOf(rule.flare))) end
		local c = rule.band and rule.band._color
		if not (c and near(c[4], 0.6, 0.001)) then
			fail(scenario, ("minimal flares rule %d at strength %s, not its 0.6"):format(i, tostring(c and c[4])))
		end
	end
	Mock.advance(1)
	FT.settle()
	for i, rule in ipairs(r.rules) do
		if (rule._alpha or 0) > 0.001 then fail(scenario, ("rule %d was left lit after its flare"):format(i)) end
	end
end)

-- ------------------------------------------------------------------ 6
-- The crack stays under the words: alpha only, its top under the lowest line's
-- bottom and inside the bottom eight units, at hunt37's eight sizes and the
-- smallest panel there is.
local SIZES = {
	{ name = "default" },
	{ name = "large", p = { 320, 58, 17, 40 } },
	{ name = "extreme: 220 wide, icon 40, font 17", p = { 220, 48, 17, 40 } },
	{ name = "the biggest icon at the default height", p = { 220, 44, 13, 36 } },
	{ name = "a tiny icon", p = { 220, 44, 13, 16 } },
	{ name = "tall: 320 x 72, icon 64", p = { 320, 72, 17, 64 } },
	{ name = "round icon", edit = function(p) p.roundIcon = true end },
	{ name = "accents off", edit = function(p) p.accentMode = "off" end },
	{ name = "the smallest panel: 80 x 20, icon 12", p = { 80, 20, 13, 12 } },
}

withTree(T .. "the crack stays under the words", ANNA, function(ns, scenario)
	for _, size in ipairs(SIZES) do
		local r = upIn(ns, scenario, "glass", function(p)
			if size.p then p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], size.p[3], size.p[4] end
			if size.edit then size.edit(p) end
		end)
		local crack = r.crack
		if not (crack and crack.split and crack.band) then fail(scenario, "SKIPPED -- the crack is not reachable") return end
		if not tostring(crack.band._file):find("Textures\\Crack", 1, true) then
			fail(scenario, "the crack is not drawn from Textures/Crack.tga")
		end
		local before = plays(crack.split)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		if plays(crack.split) ~= before + 1 then fail(scenario, size.name .. ": a refusal did not crack the ground") end
		for _, a in ipairs(crack.split._anims) do
			if a._kind ~= "Alpha" then fail(scenario, size.name .. ": the crack is " .. tostring(a._kind) .. "d, not only faded") end
		end
		local pb = FT.span(r.art, "y")
		local cb, ct = FT.span(crack.band, "y")
		if not (pb and cb) then
			fail(scenario, size.name .. ": the crack has no rectangle")
		else
			if ct - pb > 8 + 1e-6 then
				fail(scenario, ("%s: the crack reaches %.1f up from the bottom, past the bottom eight units"):format(size.name, ct - pb))
			end
			if cb - pb < 1 - 1e-6 then fail(scenario, ("%s: the crack lies on the panel's bottom edge"):format(size.name)) end
			-- Under the lowest line of words that is shown.
			local lowest
			for _, fs in ipairs({ r.name, r.sub }) do
				if fs and FT.visible(fs) and (fs._text or "") ~= "" then
					local b = FT.span(fs, "y")
					if b and (not lowest or b < lowest) then lowest = b end
				end
			end
			if lowest and ct > lowest + 1e-6 then
				fail(scenario, ("%s: the crack's top at %.1f is over the words, whose bottom is at %.1f"):format(size.name, ct, lowest))
			end
		end
		-- And from the icon's edge toward the right, not under the icon.
		local iconR = select(2, FT.span(r.icon, "x"))
		local cl = FT.span(crack.band, "x")
		if iconR and cl and cl < iconR - 1e-6 then fail(scenario, size.name .. ": the crack runs under the icon") end
		Mock.advance(1)
		FT.settle()
		if (crack._alpha or 0) > 0.001 then fail(scenario, size.name .. ": the crack was left lit") end
	end
end)

-- ------------------------------------------------------------------ 7
-- A refusal breaks the ward: the edge flashes red, the crack opens, the top
-- rule sputters, the words take a seven-step shake that sums to nothing, peaks
-- at 5 and ends at half a unit; nothing of a landing plays; the icon greys.
withTree(T .. "a refusal breaks the ward", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local g = newGroups(r)
	local before = counts(g)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local after = counts(g)
	for _, name in ipairs({ "edgeReject", "split", "flicker" }) do
		if after[name] ~= before[name] + 1 then fail(scenario, ("a refusal played %s %d times"):format(name, after[name] - before[name])) end
	end
	for _, name in ipairs({ "edgeLand", "flare1", "flare2", "shine" }) do
		if after[name] ~= before[name] then fail(scenario, "a refusal played the landing's " .. name) end
	end
	-- The edge in the break's red, 0.30 s, peak 0.35.
	local c = r.edgeLight.pieces[1]._color
	if not (c and near(c[1], 1.00, 0.001) and near(c[2], 0.42, 0.001) and near(c[3], 0.20, 0.001)) then
		fail(scenario, "the edge does not flash in the refusal's red-amber")
	end
	if not near(FT.groupLength(g.edgeReject), 0.30, 0.001) then
		fail(scenario, ("the edge's red flash lasts %.2f s, not 0.30"):format(FT.groupLength(g.edgeReject)))
	end
	if peakOf(g.edgeReject) > 0.35 + 1e-6 then fail(scenario, ("the edge's red flash peaks at %.2f, over 0.35"):format(peakOf(g.edgeReject))) end
	-- The crack: 0.40 s, peak 0.85, in the same red.
	if not near(FT.groupLength(g.split), 0.40, 0.001) then
		fail(scenario, ("the crack lasts %.2f s, not 0.40"):format(FT.groupLength(g.split)))
	end
	if not near(peakOf(g.split), 0.85, 0.001) then fail(scenario, ("the crack peaks at %.2f, not 0.85"):format(peakOf(g.split))) end
	local cc = r.crack.band._color
	if not (cc and near(cc[1], 1.00, 0.001) and near(cc[2], 0.42, 0.001) and near(cc[3], 0.20, 0.001)) then
		fail(scenario, "the crack is not the refusal's red-amber")
	end
	if r.crack.band._blend ~= "ADD" then fail(scenario, "the crack is not light") end
	-- The top rule sputters: four fades in four orders, 0.30 s, lit, dimmed,
	-- lit, gone; in the break's red at the look's strength.
	local flicker = g.flicker
	local steps = {}
	for _, a in ipairs(flicker._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "the sputter moves the rule: " .. tostring(a._kind)) end
		steps[#steps + 1] = a
	end
	table.sort(steps, function(a, b) return (a._order or 1) < (b._order or 1) end)
	if #steps ~= 4 then
		fail(scenario, ("the sputter has %d steps, not four"):format(#steps))
	elseif not (steps[1]._toAlpha > steps[2]._toAlpha and steps[3]._toAlpha > steps[2]._toAlpha and near(steps[4]._toAlpha, 0)) then
		fail(scenario, "the sputter does not dim between two lit steps and end at nothing")
	end
	if not near(FT.groupLength(flicker), 0.30, 0.001) then
		fail(scenario, ("the sputter lasts %.2f s, not 0.30"):format(FT.groupLength(flicker)))
	end
	local rc = r.rules[1].band._color
	if not (rc and near(rc[1], 1.00, 0.001) and near(rc[2], 0.42, 0.001) and near(rc[3], 0.20, 0.001) and near(rc[4], 1, 0.001)) then
		fail(scenario, "the top rule does not sputter in the refusal's red-amber at full strength on glass")
	end
	if plays(r.rules[2].flicker or {}) ~= 0 and r.rules[2].flicker then fail(scenario, "the bottom rule sputtered as well") end
	-- The shake: seven steps of 0.04 s, -3 first, summing to nothing, peak 5,
	-- the last half a unit, never left of -3.
	local shake = r.shake
	local dx, sum, peak = {}, 0, 0
	for _, a in ipairs(shake._anims) do
		dx[a._order or 1] = a._offset and a._offset[1] or 0
		if a._offset and a._offset[2] ~= 0 then fail(scenario, "the shake moves the words up or down") end
		if not near(a._duration, 0.04, 0.0001) then fail(scenario, ("a shake step takes %.3f s, not 0.04"):format(a._duration or 0)) end
	end
	if #dx ~= 7 then fail(scenario, ("the shake has %d steps, not seven"):format(#dx)) end
	for _, d in ipairs(dx) do sum = sum + d peak = math.max(peak, math.abs(d)) end
	if not near(sum, 0, 1e-6) then fail(scenario, ("the shake's steps add up to %.2f"):format(sum)) end
	if not near(peak, 5) then fail(scenario, ("the shake peaks at %.1f, not 5"):format(peak)) end
	if not near(dx[1], -3) then fail(scenario, ("the shake starts at %.1f, not -3 toward the icon"):format(dx[1] or 0)) end
	if not near(math.abs(dx[#dx] or 0), 0.5) then fail(scenario, ("the shake ends at %.2f, not half a unit"):format(dx[#dx] or 0)) end
	local x = 0
	for _, d in ipairs(dx) do
		x = x + d
		if x < -3 - 1e-6 then fail(scenario, ("the shake swings the words %.1f left, past SHAKE_LEFT"):format(-x)) end
	end
	if not near(FT.groupLength(shake), 0.28, 0.001) then
		fail(scenario, ("the shake lasts %.2f s, not 0.28"):format(FT.groupLength(shake)))
	end
	-- Everything of it parked once the half-second is over.
	Mock.advance(0.6)
	FT.settle()
	for _, item in ipairs({ { "the edge", r.edgeLight }, { "the crack", r.crack }, { "the top rule", r.rules[1] } }) do
		if (item[2]._alpha or 0) > 0.001 then fail(scenario, item[1] .. " was left lit after the refusal") end
	end
end)

-- ------------------------------------------------------------------ 8
-- A refusal greys the icon for the outcome and gives its colour back when the
-- outcome is cleared -- with the queue empty too, where no person is painted
-- after it -- and never greys it under a look from Looks/.
withTree(T .. "a refusal greys the icon and gives it back", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local S = ns.Prompt.state
	if r.icon._desaturated then fail(scenario, "SKIPPED -- the icon is grey before anything was refused") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if not S.iconGreyed then fail(scenario, "the icon is grey and the flag that says so is down") end
	-- Still grey on the scans of the outcome.
	Mock.advance(0.3)
	ns.addon:Tick()
	if not r.icon._desaturated then fail(scenario, "the icon got its colour back while the refusal was still up") end
	-- The outcome runs out with Anna still on the panel: colour back.
	Mock.advance(0.4)
	ns.addon:Tick()
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	if S.iconGreyed then fail(scenario, "the flag stayed up after the icon got its colour back") end
	-- And with the queue empty after the refusal (the usual case: the press
	-- retired them), where nobody is painted after the outcome.
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not r.icon._desaturated then fail(scenario, "SKIPPED -- the second refusal did not grey the icon") return end
	ns.BlockPerson("Anna Aim")
	wipe(ns.owed)
	Mock.advance(0.7)
	ns.addon:Tick()
	if r.icon._desaturated or S.iconGreyed then
		fail(scenario, "the icon stayed grey after a refusal over an empty queue ran out")
	end
	-- Under a look from Looks/ the icon is the look's: Prompt never greys it.
	local rl = upIn(ns, scenario, "leather")
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if S.iconGreyed then fail(scenario, "Prompt greyed the icon under a look from Looks/") end
	Mock.advance(1)
	ns.addon:Tick()
	if S.iconGreyed then fail(scenario, "the flag went up under a look from Looks/") end
	-- Calm greys it too: a state, not a motion.
	local rc = upIn(ns, scenario, "glass", function(p) p.effects = "calm" end)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not rc.icon._desaturated then fail(scenario, "on Calm a refusal did not grey the icon") end
	Mock.advance(0.7)
	ns.addon:Tick()
	if rc.icon._desaturated then fail(scenario, "on Calm the icon stayed grey after the refusal ran out") end
end)

-- ------------------------------------------------------------------ 9
-- Ten scans of a passer-by after an outcome has cleared ask the icon for
-- nothing: giving the colour back is a flag's cost, and a client call only
-- when there is grey to undo.
withTree(T .. "an ungreyed icon costs nothing", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not r.icon._desaturated then fail(scenario, "SKIPPED -- the refusal did not grey the icon") return end
	Mock.advance(0.7)
	ns.addon:Tick()
	if r.icon._desaturated then fail(scenario, "SKIPPED -- the icon did not get its colour back") return end
	-- Anna becomes a passer-by: nobody owed, nothing to undo.
	wipe(ns.owed)
	ns.addon:Tick()
	local original = r.icon.SetDesaturated
	local calls = 0
	r.icon.SetDesaturated = function(self, on)
		calls = calls + 1
		return original(self, on)
	end
	for _ = 1, 10 do
		Mock.advance(0.4)
		ns.addon:Tick()
	end
	r.icon.SetDesaturated = original
	if calls > 0 then
		fail(scenario, ("ten scans with no grey to undo made %d SetDesaturated calls on the icon"):format(calls))
	end
end)

-- ------------------------------------------------------------------ 10
-- Everything stops: a repaint about somebody else mid-flourish, and a look
-- from Looks/ applied mid-flourish, leave nothing lit and nothing playing.
withTree(T .. "a restyle leaves nothing lit", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local g = newGroups(r)
	local frames = { { "the edge", r.edgeLight }, { "the crack", r.crack }, { "the top rule", r.rules[1] },
		{ "the bottom rule", r.rules[2] }, { "the wave", r.shine } }
	local function nothingLit(what)
		for name, group in pairs(g) do
			if group._playing then fail(scenario, ("%s left %s playing"):format(what, name)) end
		end
		for _, item in ipairs(frames) do
			if (item[2]._alpha or 0) > 0.001 then fail(scenario, ("%s left %s lit"):format(what, item[1])) end
		end
	end
	-- A repaint about somebody else, 0.05 s into a landing.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(0.05)
	if not (g.edgeLand._playing and g.shine._playing and g.fade._playing) then
		fail(scenario, "SKIPPED -- the landing is not under way 0.05 s in")
		return
	end
	ns.Prompt:StopFlourishes()
	nothingLit("a repaint mid-landing")
	-- The same 0.05 s into a refusal.
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(0.05)
	if not (g.edgeReject._playing and g.split._playing and g.flicker._playing) then
		fail(scenario, "SKIPPED -- the refusal is not under way 0.05 s in")
		return
	end
	ns.Prompt:StopFlourishes()
	nothingLit("a repaint mid-refusal")
	-- A look from Looks/ applied mid-refusal: stopped, and the icon in colour.
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(0.05)
	if not g.split._playing then fail(scenario, "SKIPPED -- the second refusal is not under way") return end
	ns.db.profile.prompt.style = "leather"
	ns.Prompt:ApplyStyle()
	nothingLit("a look applied mid-refusal")
	-- The grey handed back before the look took the icon (the look may grey
	-- it again for the same refusal: that grey is its own).
	if ns.Prompt.state.iconGreyed then fail(scenario, "a look applied mid-refusal inherited the grey icon") end
	for _, item in ipairs({ { "the edge", r.edgeLight }, { "the crack", r.crack }, { "the wash", r.wash } }) do
		if FT.visible(item[2]) then fail(scenario, item[1] .. " still shows under a look from Looks/") end
	end
	-- And back on glass they are shown again.
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	for _, item in ipairs({ { "the edge", r.edgeLight }, { "the crack", r.crack }, { "the wash", r.wash } }) do
		if not FT.visible(item[2]) then fail(scenario, item[1] .. " stayed hidden after a look from Looks/") end
	end
end)

-- ------------------------------------------------------------------ 11
-- Calm plays none of it and keeps the wash static, set and left at its old
-- alphas; a quiet fight plays none of it either.
withTree(T .. "Calm keeps the static wash", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass", function(p) p.effects = "calm" end)
	local g = newGroups(r)
	local before = counts(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local c = r.fill._color
	if not (c and near(c[4], 0.20, 0.001)) then
		fail(scenario, ("on Calm the landing's wash is at alpha %s, not the static 0.20"):format(tostring(c and c[4])))
	end
	if not near(r.wash._alpha or 1, 1, 0.001) then fail(scenario, "on Calm the wash's frame is not at full") end
	if not FT.visible(r.fill) then fail(scenario, "on Calm the wash is not shown") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	c = r.fill._color
	if not (c and near(c[4], 0.15, 0.001)) then
		fail(scenario, ("on Calm the refusal's wash is at alpha %s, not the static 0.15"):format(tostring(c and c[4])))
	end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	c = r.fill._color
	if not (c and near(c[4], 0.14, 0.001)) then
		fail(scenario, ("on Calm an unconfirmed cast's wash is at alpha %s, not the static 0.14"):format(tostring(c and c[4])))
	end
	local after = counts(g)
	for name in pairs(g) do
		if after[name] ~= before[name] then fail(scenario, "with Effects on Calm the " .. name .. " still played") end
	end
	-- A fight with "Keep the prompt still in combat": nothing plays, the wash
	-- is not even painted.
	local rf = upIn(ns, scenario, "glass", function(p) p.hideInCombat = true end)
	local gf = newGroups(rf)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	FT.settle()
	local b = counts(gf)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local a = counts(gf)
	for name in pairs(gf) do
		if a[name] ~= b[name] then fail(scenario, "with the prompt kept still in combat the " .. name .. " still played") end
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

-- ------------------------------------------------------------------ 12
-- The old band's file is gone, and nothing draws it: the wave is Shock.tga.
withTree(T .. "the old sweep is retired", {}, function(_, scenario)
	local f = io.open(dir .. "/Textures/Sweep.tga", "rb")
	if f then
		f:close()
		fail(scenario, "Textures/Sweep.tga still ships, and nothing draws it")
	end
	for _, file in ipairs({ "Prompt/Prompt.lua", "Prompt/Panel.lua", "Prompt/Effects.lua" }) do
		local source = assert(io.open(dir .. "/" .. file, "r")):read("*a")
		if source:find("Textures\\\\Sweep", 1, true) then fail(scenario, file .. " still names Textures/Sweep.tga") end
	end
	local gen = assert(io.open(dir .. "/tools/make-glow.py", "r")):read("*a")
	if gen:find('"Sweep"', 1, true) or gen:find("def sweep(", 1, true) then
		fail(scenario, "tools/make-glow.py still draws Sweep.tga")
	end
	local prompt = assert(io.open(dir .. "/Prompt/Prompt.lua", "r")):read("*a")
	if not prompt:find("Textures\\\\Shock\"", 1, true) then fail(scenario, "Prompt/Prompt.lua does not name Textures/Shock.tga") end
	if not prompt:find("Textures\\\\Crack\"", 1, true) then fail(scenario, "Prompt/Prompt.lua does not name Textures/Crack.tga") end
	for _, name in ipairs({ "Shock", "Crack" }) do
		local t = io.open(dir .. "/Textures/" .. name .. ".tga", "rb")
		if t then t:close() else fail(scenario, "Textures/" .. name .. ".tga is not in the package") end
	end
end)

-- ------------------------------------------------------------------ 13
-- The edge's light is the material itself, lit: on glass a copy of the pane's
-- light laid piece for piece over it, drawn as light with its middle piece
-- dark, so the flash lands on the cut edge and nothing lights under the words,
-- and the landing's colour goes on those pieces.
withTree(T .. "the edge light is the material", ANNA, function(ns, scenario)
	local function same(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.01 end
	for _, case in ipairs({ { "glass", "glass", "GlassLight", "glassLight" } }) do
		local style, own, file, material = case[1], case[2], case[3], case[4]
		local r = upIn(ns, scenario, style)
		local edge = r.edgeLight
		if edge.pieces ~= edge[own] then fail(scenario, style .. ": the edge lights with pieces that are not the glass's") end
		if type(edge.pieces) ~= "table" or #edge.pieces ~= 9 then
			fail(scenario, style .. ": the edge's light is not a nine-slice")
		else
			for i, piece in ipairs(edge.pieces) do
				if not tostring(piece._file):find(file, 1, true) then
					fail(scenario, ("%s: edge piece %d is drawn from %s, not %s"):format(style, i, tostring(piece._file), file))
				end
				if piece._blend ~= "ADD" then fail(scenario, ("%s: edge piece %d is not drawn as light"):format(style, i)) end
				if piece._parent ~= edge then fail(scenario, ("%s: edge piece %d is not on the edge's frame"):format(style, i)) end
				if i == 5 then
					if FT.visible(piece) then fail(scenario, style .. ": the edge's middle piece is lit, under the words") end
				else
					if not FT.visible(piece) then fail(scenario, ("%s: edge piece %d is hidden"):format(style, i)) end
					-- Laid exactly where the material's own piece lies.
					local twin = r[material][i]
					for _, axis in ipairs({ "x", "y" }) do
						local lo, hi = FT.span(piece, axis)
						local tlo, thi = FT.span(twin, axis)
						if not (same(lo, tlo) and same(hi, thi)) then
							fail(scenario, ("%s: edge piece %d spans %s..%s on %s, the material's %s..%s"):format(style, i,
								tostring(lo), tostring(hi), axis, tostring(tlo), tostring(thi)))
							break
						end
					end
				end
			end
		end
		-- The landing's colour lands on the look's own pieces.
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		local cr, cg, cb = ns.Prompt:AccentColor("owed")
		local er, eg, eb = ns.Prompt.lib.Tint(cr, cg, cb, 0.55)
		local c = edge.pieces and edge.pieces[1] and edge.pieces[1]._color
		if not (c and near(c[1], er, 0.001) and near(c[2], eg, 0.001) and near(c[3], eb, 0.001)) then
			fail(scenario, style .. ": the landing's colour did not reach the edge's own pieces")
		end
		-- Over the material and the bezel (a frame of its own, above the art's
		-- textures) and under the text.
		if (edge._level or 0) <= (r.art._level or 0) then fail(scenario, style .. ": the edge's light is not over the material") end
		if (edge._level or 0) >= (r.textLayer._level or 0) then fail(scenario, style .. ": the edge's light is over the text") end
		Mock.advance(1)
		FT.settle()
	end
end)

-- ------------------------------------------------------------------ 13
-- A refusal's grey is given back at every place an outcome is cleared, each
-- the way the player really gets there, not only where it runs out: the
-- panel unlocked for a drag (its hint is not about anybody), a fight held on
-- a panel that is off, a press that moves on, a person painted afresh. The
-- greyed icon is the outcome's, and none of these is the next person's.
local function refused(ns, scenario, name)
	local r = upIn(ns, scenario, "glass")
	ns.Prompt:ShowOutcome("failed", name or "Anna Aim", "Out of range.")
	if not r.icon._desaturated then return nil end
	return r
end

withTree(T .. "an unlock hint gives the grey back", ANNA, function(ns, scenario)
	local r = refused(ns, scenario)
	if not r then fail(scenario, "SKIPPED -- the refusal did not grey the icon") return end
	ns.db.profile.prompt.locked = false
	ns.addon:Tick()
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the refusal ran out before the unlock") return end
	if r.icon._desaturated or ns.Prompt.state.iconGreyed then
		fail(scenario, "the icon stayed grey under the unlock hint while the refusal was still live")
	end
	ns.db.profile.prompt.locked = true
end)

withTree(T .. "a held panel gives the grey back", ANNA, function(ns, scenario)
	local r = refused(ns, scenario)
	if not r then fail(scenario, "SKIPPED -- the refusal did not grey the icon") return end
	-- Switched off with a fight on: the panel cannot go, so it is held and
	-- says why, over an outcome that has not run out.
	ns.db.profile.enabled = false
	Mock.inCombat = true
	ns.addon:Tick()
	Mock.inCombat = false
	ns.db.profile.enabled = true
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the refusal ran out before the fight") return end
	if r.icon._desaturated or ns.Prompt.state.iconGreyed then
		fail(scenario, "the icon stayed grey on a panel held inert while the refusal was still live")
	end
end)

withTree(T .. "a press that moves on gives the grey back", ANNA, function(ns, scenario)
	local r = refused(ns, scenario)
	if not r then fail(scenario, "SKIPPED -- the refusal did not grey the icon") return end
	-- The repaint MovedOn asks for would give it back as it paints a person;
	-- without it, MovedOn must have done so itself.
	local Prompt = ns.Prompt
	local refresh = Prompt.Refresh
	Prompt.Refresh = function() end
	local top = Prompt.state.heldEntry
	if top then Prompt:MovedOn(top) end
	Prompt.Refresh = refresh
	if not top then fail(scenario, "SKIPPED -- nobody is on the panel to move on from") return end
	if r.icon._desaturated or Prompt.state.iconGreyed then
		fail(scenario, "the icon stayed grey after a press moved on from the refusal")
	end
end)

withTree(T .. "a fresh paint gives the grey back", ANNA, function(ns, scenario)
	local r = refused(ns, scenario)
	if not r then fail(scenario, "SKIPPED -- the refusal did not grey the icon") return end
	local top = ns.Prompt.state.heldEntry
	if not top then fail(scenario, "SKIPPED -- nobody is on the panel to paint") return end
	ns.Prompt:Paint(top, 0)
	if r.icon._desaturated or ns.Prompt.state.iconGreyed then
		fail(scenario, "the icon stayed grey after a person was painted afresh")
	end
end)

-- ------------------------------------------------------------------ 14
-- The wash is played once per outcome, but a fill something hid while the
-- outcome was live (a look from Looks/ taking the panel and giving it back,
-- the unlock hint and the lock again) is shown again with the next repaint
-- and washes the rest of the outcome: the stamp says the wash was played,
-- not that its fill is on screen.
withTree(T .. "a fill hidden mid-outcome comes back", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local p = ns.db.profile.prompt
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not FT.visible(r.fill) then fail(scenario, "SKIPPED -- the refusal did not show the wash") return end
	local plays0 = plays(r.wash.fade)
	Mock.advance(0.15)
	p.style = "leather"
	ns.Prompt:ApplyStyle()
	Mock.advance(0.1)
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the refusal ran out during the restyle") return end
	if not FT.visible(r.fill) then
		fail(scenario, "the wash's fill stayed hidden for the rest of the outcome after a look from Looks/ came and went")
	end
	if plays(r.wash.fade) ~= plays0 + 1 then
		fail(scenario, ("the wash played %d more times after the restyle, not once"):format(plays(r.wash.fade) - plays0))
	end
	-- And an unlock hint and the lock again, on a fresh outcome.
	Mock.advance(1)
	FT.settle()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(0.1)
	p.locked = false
	ns.addon:Tick()
	p.locked = true
	ns.addon:Tick()
	if ns.Prompt:OutcomeLive() and not FT.visible(r.fill) then
		fail(scenario, "the wash's fill stayed hidden after the unlock hint went")
	end
	-- Shown, it is not played again by every scan.
	local n = plays(r.wash.fade)
	ns.addon:Tick()
	ns.addon:Tick()
	if plays(r.wash.fade) ~= n then fail(scenario, "a shown wash was played again by a repaint") end
end)
