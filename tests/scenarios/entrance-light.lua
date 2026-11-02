-- entrance-light: the rules of light the entrance draws, the words held back
-- a beat, the glint a favour runs along the rules, and what Calm and a look
-- from Looks/ keep of it.
--
-- When the prompt comes up on glass, framed or minimal, two rules of light
-- draw themselves out from the icon along the panel's top and bottom edges
-- while the panel rises, and the words arrive a beat behind them
-- (Prompt/Effects.lua, Prompt:PlayIntro and BuildAnimations; Prompt/Panel.lua
-- places the rules). A favour arriving runs a glint along both rules in place
-- of the band of light that used to cross the panel. Calm plays none of it,
-- and nor does a look from Looks/.
--
-- The one thing the words' reveal must never do is leave textLayer dim: every
-- stop that cuts it short puts the words back at full -- and only on the
-- three looks drawn here, because under a look from Looks/ textLayer's alpha
-- is the look's own fight dim, which a flourish in combat must leave alone.
--
-- The evidence is the frame tree's (tests/frametree.lua); the geometry of a
-- rule mid-draw comes from tests/fxgeometry.lua, which reads a Scale about the
-- origin it names (the rules grow about their left end).

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree
local G = dofile(dir .. "/tests/fxgeometry.lua")

local T = "entrance-light: "
local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ANNA_BERT = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }

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

-- The prompt in `style` on Full, `edit` applied first, Anna on the panel as a
-- passer-by (not owed), the entrance it came up with over and parked.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.flashStyle, p.effects, p.hideInCombat = style, "pulse", "full", false
	p.showIcon, p.roundIcon, p.showSub = true, false, true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	Mock.advance(1)
	FT.settle()
	return ns.Prompt:Regions(), p
end

-- The panel taken down and brought up again by the next scan: the entrance,
-- just started. Answers whether it came up.
local function comeUp(ns)
	ns.Prompt:GetButton():Hide()
	ns.addon:Tick()
	return ns.Prompt:GetButton():IsShown()
end

local function overlaps(a, b)
	return a[1] < b[3] - 1e-6 and b[1] < a[3] - 1e-6 and a[2] < b[4] - 1e-6 and b[2] < a[4] - 1e-6
end

-- The alpha the words' own frame is at `now`: its own, replaced by a group of
-- its own while one plays (the reveal, the outcome's dip). The panel's rise
-- above it fades the whole panel, words included, and is not the question.
local function wordsAlpha(r, now)
	local own = r.textLayer._alpha
	if own == nil then own = 1 end
	local e = G.effectOf(r.textLayer, now)
	if e and e.alpha ~= nil then own = e.alpha end
	return own
end

-- ------------------------------------------------------------------ 1
-- The entrance: the rise, the two rules drawn out from the icon along their
-- length only, and the words a beat behind, full by 0.24 s and left at full.
withTree(T .. "the words arrive with the panel", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local draws = { r.rules and r.rules[1] and r.rules[1].draw, r.rules and r.rules[2] and r.rules[2].draw }
	if not (draws[1] and draws[2] and r.reveal and r.intro and r.introCalm) then
		fail(scenario, "SKIPPED -- the entrance's groups are not reachable")
		return
	end
	local before = { intro = plays(r.intro), reveal = plays(r.reveal), calm = plays(r.introCalm),
		plays(draws[1]), plays(draws[2]) }
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	if plays(r.intro) ~= before.intro + 1 then
		fail(scenario, ("the rise played %d times for one entrance"):format(plays(r.intro) - before.intro))
	end
	if plays(r.reveal) ~= before.reveal + 1 then
		fail(scenario, ("the words' reveal played %d times for one entrance"):format(plays(r.reveal) - before.reveal))
	end
	for i, d in ipairs(draws) do
		if plays(d) ~= before[i] + 1 then
			fail(scenario, ("rule %d drew itself %d times for one entrance"):format(i, plays(d) - before[i]))
		end
	end
	if plays(r.introCalm) ~= before.calm then fail(scenario, "Calm's fade played on Full") end
	-- Each draw: one Scale, along the length only, about the left end; 0.46 s
	-- in all, and the mock saw SetScaleFrom(0.04, 1).
	for i, d in ipairs(draws) do
		local scales = 0
		for _, a in ipairs(d._anims) do
			if a._kind == "Scale" then
				scales = scales + 1
				local f, to = a._scaleFrom or {}, a._scaleTo or {}
				if not (near(f[1], 0.04) and near(f[2], 1) and near(to[1], 1) and near(to[2], 1)) then
					fail(scenario, ("rule %d's scale is not along its length alone, 0.04 to 1: %s, %s -> %s, %s"):format(
						i, tostring(f[1]), tostring(f[2]), tostring(to[1]), tostring(to[2])))
				end
				if not (a._origin and a._origin[1] == "LEFT") then
					fail(scenario, ("rule %d does not grow about its left end: %s"):format(i, tostring(a._origin and a._origin[1])))
				end
			end
		end
		if scales ~= 1 then fail(scenario, ("rule %d's draw has %d scales, not one"):format(i, scales)) end
		if not near(FT.groupLength(d), 0.46, 0.001) then
			fail(scenario, ("rule %d's draw lasts %.2f s, not 0.46"):format(i, FT.groupLength(d)))
		end
	end
	-- The words: fades only, held at nothing as the rules start, full by
	-- 0.24 s and left there (the group ends at 1, nothing parks it).
	if FT.groupLength(r.reveal) > 0.24 + 1e-6 then
		fail(scenario, ("the words take %.2f s to arrive, over the 0.24 the panel allows"):format(FT.groupLength(r.reveal)))
	end
	local last
	for _, a in ipairs(r.reveal._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "the words' reveal moves them: " .. tostring(a._kind)) end
		if not last or (a._order or 1) > (last._order or 1) then last = a end
	end
	if not (last and near(last._toAlpha, 1)) then fail(scenario, "the words' reveal does not end with the words at full") end
	local now = GetTime()
	if wordsAlpha(r, now + 0.04) > 0.001 then
		fail(scenario, ("the words are not held back as the rules start: alpha %.2f at 0.04 s"):format(wordsAlpha(r, now + 0.04)))
	end
	Mock.advance(0.24)
	FT.settle()
	if not near(wordsAlpha(r, GetTime()), 1, 0.001) then
		fail(scenario, ("the words are at alpha %.2f 0.24 s in, not full"):format(wordsAlpha(r, GetTime())))
	end
	-- The rules in the reason's colour a third of the way to white, at full
	-- strength on glass: Anna is a passer-by, so the colour is nearby's.
	local cr, cg, cb = ns.Prompt:AccentColor("nearby")
	local er, eg, eb = ns.Prompt.lib.Tint(cr, cg, cb, 0.35)
	for i, rule in ipairs(r.rules) do
		local c = rule.band and rule.band._color
		if not (c and near(c[1], er, 0.001) and near(c[2], eg, 0.001) and near(c[3], eb, 0.001)) then
			fail(scenario, ("rule %d is not drawn in the reason's colour taken a third to white"):format(i))
		elseif not near(c[4], 1, 0.001) then
			fail(scenario, ("rule %d is drawn at strength %.2f on glass, not full"):format(i, c[4]))
		end
	end
	-- Parked: once the draws have run, both rules rest at nothing.
	Mock.advance(0.3)
	FT.settle()
	for i, rule in ipairs(r.rules) do
		if rule.draw._playing then fail(scenario, ("rule %d is still drawing 0.54 s in"):format(i)) end
		if (rule._alpha or 0) > 0.001 then fail(scenario, ("rule %d was left lit after its draw"):format(i)) end
	end
end)

-- ------------------------------------------------------------------ 2
-- The rules lie a unit and a half inside the top and the bottom and never
-- meet the name or the reason line while they draw, at hunt37's eight sizes,
-- in each of the three looks drawn here. The geometry is fxgeometry's, which
-- knows the rules grow about their left end.
local SIZES = {
	{ name = "default" },
	{ name = "large", p = { 320, 58, 17, 40 } },
	{ name = "extreme: 220 wide, icon 40, font 17", p = { 220, 48, 17, 40 } },
	{ name = "the biggest icon at the default height", p = { 220, 44, 13, 36 } },
	{ name = "a tiny icon", p = { 220, 44, 13, 16 } },
	{ name = "tall: 320 x 72, icon 64", p = { 320, 72, 17, 64 } },
	{ name = "round icon", edit = function(p) p.roundIcon = true end },
	{ name = "accents off", edit = function(p) p.accentMode = "off" end },
}
local TIMES = { 0.01, 0.03, 0.05, 0.08, 0.12, 0.16, 0.20, 0.26, 0.30, 0.36, 0.42, 0.46 }

for _, style in ipairs({ "glass", "framed", "minimal" }) do
	withTree(T .. "the rules stay off the words, in " .. style, ANNA, function(ns, scenario)
		for _, size in ipairs(SIZES) do
			local r = upIn(ns, scenario, style, function(p)
				if size.p then p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], size.p[3], size.p[4] end
				if size.edit then size.edit(p) end
			end)
			local tag = style .. ", " .. size.name
			local art = r.art
			local pb, pt = FT.span(art, "y")
			-- At rest: a unit and a half inside each edge, from the icon's
			-- middle to two units short of the right edge.
			local _, ruleTop = FT.span(r.rules[1], "y")
			local ruleBottom = FT.span(r.rules[2], "y")
			if not (ruleTop and near(pt - ruleTop, 1.5, 0.01)) then
				fail(scenario, ("%s: the top rule sits %s under the panel's top, not 1.5"):format(tag, tostring(ruleTop and pt - ruleTop)))
			end
			if not (ruleBottom and near(ruleBottom - pb, 1.5, 0.01)) then
				fail(scenario, ("%s: the bottom rule sits %s over the panel's bottom, not 1.5"):format(tag, tostring(ruleBottom and ruleBottom - pb)))
			end
			local al, ar = FT.span(art, "x")
			local rl, rr = FT.span(r.rules[1], "x")
			local iconL, iconR = FT.span(r.icon, "x")
			if not (rl and iconL and near(rl, (iconL + iconR) / 2, 0.01)) then
				fail(scenario, ("%s: the rule starts at %s, not at the icon's middle %s"):format(tag, tostring(rl), tostring(iconL and (iconL + iconR) / 2)))
			end
			if not (rr and near(ar - rr, 2, 0.01)) then
				fail(scenario, ("%s: the rule ends %s short of the right edge, not 2"):format(tag, tostring(rr and ar - rr)))
			end
			if not comeUp(ns) then fail(scenario, "SKIPPED -- " .. tag .. ": the panel did not come up") return end
			local seen, last = 0, 0
			for _, t in ipairs(TIMES) do
				Mock.advance(t - last)
				last = t
				local now = GetTime()
				local texts = {}
				for _, fs in ipairs({ r.name, r.sub }) do
					if fs and FT.visible(fs) and (fs._text or "") ~= "" then
						local L, B, Rt, Tp = G.rectAt(fs, art, now)
						if L then texts[#texts + 1] = { L, B, Rt, Tp, fs = fs } end
					end
				end
				for i, rule in ipairs(r.rules) do
					local band = rule.band
					if band and G.seenAt(band, art, now) then
						local L, B, Rt, Tp = G.rectAt(band, art, now)
						if L then
							seen = seen + 1
							for _, text in ipairs(texts) do
								if overlaps({ L, B, Rt, Tp }, text) then
									fail(scenario, ("%s, %.2f s: rule %d covers the %s: it lies %.1f to %.1f, the text %.1f to %.1f"):format(
										tag, t, i, text.fs == r.name and "name" or "reason line", B, Tp, text[2], text[4]))
								end
							end
							-- A unit inside the panel's edge, where every light is held to.
							if Tp > pt - 1 + 1e-6 or B < pb + 1 - 1e-6 then
								fail(scenario, ("%s, %.2f s: rule %d passes within a unit of the panel's %s: %.1f to %.1f, the panel %.1f to %.1f"):format(
									tag, t, i, Tp > pt - 1 and "top" or "bottom", B, Tp, pb, pt))
							end
							-- And grows out from its left end, which stays put.
							if not near(L, rl, 0.01) then
								fail(scenario, ("%s, %.2f s: rule %d's left end moved from %.1f to %.1f as it drew"):format(tag, t, i, rl, L))
							end
						end
					end
				end
			end
			if seen < 8 then fail(scenario, tag .. ": the rules were not seen drawing (" .. seen .. " samples)") end
			Mock.advance(2)
			FT.settle()
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- Calm: the fade alone, and the words with the panel from the first frame.
withTree(T .. "Calm keeps the words", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass", function(p) p.effects = "calm" end)
	local groups = { intro = r.intro, reveal = r.reveal, draw1 = r.rules[1].draw, draw2 = r.rules[2].draw,
		glint1 = r.glints[1].run, glint2 = r.glints[2].run }
	local before = {}
	for name, g in pairs(groups) do before[name] = plays(g) end
	local calm = plays(r.introCalm)
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	if plays(r.introCalm) ~= calm + 1 then fail(scenario, "Calm's panel did not come up with its fade") end
	for name, g in pairs(groups) do
		if plays(g) ~= before[name] then fail(scenario, "with Effects on Calm the " .. name .. " played") end
	end
	if not near(r.textLayer._alpha or 1, 1) or not near(wordsAlpha(r, GetTime() + 0.05), 1, 0.001) then
		fail(scenario, "on Calm the words were held back behind the panel")
	end
end)

-- ------------------------------------------------------------------ 4
-- A favour arriving runs both glints once -- never the band of light across
-- the panel -- not for a passer-by, not twice for one favour, not over an
-- outcome; 0.38 s each, the run the width left of the rule, the colour the
-- reason's taken towards white; the flag the scan reads is up while they run
-- and down once both have finished or the favour leaves.
withTree(T .. "a favour's glint runs the rules", ANNA_BERT, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local runs = { r.glints and r.glints[1] and r.glints[1].run, r.glints and r.glints[2] and r.glints[2].run }
	local shine = r.shine and r.shine.anim
	if not (runs[1] and runs[2] and shine) then fail(scenario, "SKIPPED -- the glints are not reachable") return end
	local S = ns.Prompt.state
	if plays(runs[1]) + plays(runs[2]) > 0 then fail(scenario, "a passer-by on the panel ran the glint") end
	local shone = plays(shine)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	for i, run in ipairs(runs) do
		if plays(run) ~= 1 then fail(scenario, ("glint %d ran %d times for one favour"):format(i, plays(run))) end
		if not near(FT.groupLength(run), 0.38, 0.001) then
			fail(scenario, ("glint %d runs for %.2f s, not 0.38"):format(i, FT.groupLength(run)))
		end
		-- From the icon's middle (25) to two units short of the right edge
		-- (218), less its own 14: 179 at the default width.
		local off = run.move and run.move._offset
		if not (off and near(off[1], 179, 0.01) and near(off[2], 0)) then
			fail(scenario, ("glint %d runs %s units, not the 179 the rule is long"):format(i, tostring(off and off[1])))
		end
	end
	if plays(shine) ~= shone then fail(scenario, "the favour sent the band of light across the panel as well as the glint") end
	if not S.glintPlaying then fail(scenario, "the glints' flag is not up while they run") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local er, eg, eb = ns.Prompt.lib.Tint(cr, cg, cb, 0.45)
	for i, glint in ipairs(r.glints) do
		local c = glint.band and glint.band._color
		if not (c and near(c[1], er, 0.001) and near(c[2], eg, 0.001) and near(c[3], eb, 0.001) and near(c[4], 0.9, 0.001)) then
			fail(scenario, ("glint %d is not the reason's colour taken towards white at 0.9"):format(i))
		end
	end
	-- Once: the next scans are the same person owed the same favour.
	Mock.advance(0.4)
	ns.addon:Tick()
	Mock.advance(0.4)
	ns.addon:Tick()
	if plays(runs[1]) ~= 1 or plays(runs[2]) ~= 1 then fail(scenario, "the glint ran again on a scan that changed nothing") end
	FT.settle()
	if S.glintPlaying then fail(scenario, "the glints' flag stayed up after both had finished") end
	for i, glint in ipairs(r.glints) do
		if (glint._alpha or 0) > 0.001 then fail(scenario, ("glint %d was left lit after its run"):format(i)) end
	end
	-- Not over an outcome: Bert buffs you as the press on Anna lands.
	Mock.advance(1)
	FT.settle()
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	owe(ns, "Bert Beside")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(runs[1]) ~= 1 or plays(runs[2]) ~= 1 then
		fail(scenario, "the glint ran for the next favour over the confirmation of the last")
	end
	-- The favour leaving mid-run stops the glints and drops the flag.
	Mock.advance(2)
	FT.settle()
	wipe(ns.owed)
	ns.addon:Tick()
	Mock.advance(0.4)
	FT.settle()
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	if plays(runs[1]) ~= 2 then fail(scenario, "SKIPPED -- Bert's favour did not run the glint: " .. plays(runs[1])) return end
	Mock.advance(0.1)
	wipe(ns.owed)
	ns.addon:Tick()
	for i, glint in ipairs(r.glints) do
		if glint.run._playing then fail(scenario, ("glint %d kept running after the favour left the panel"):format(i)) end
		if (glint._alpha or 0) > 0.001 then fail(scenario, ("glint %d was left lit when the favour left"):format(i)) end
	end
	if S.glintPlaying then fail(scenario, "the glints' flag stayed up after the favour left") end
end)

-- ------------------------------------------------------------------ 5
-- The glint is seen while it runs: it hangs from the art, not from the rule
-- it runs, which rests at nothing; so the alphas up its chain multiply to
-- light, not to nothing.
withTree(T .. "the glint is seen", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(r.glints[1].run) == 0 then fail(scenario, "SKIPPED -- the favour did not run the glint") return end
	Mock.advance(0.10)
	local now = GetTime()
	for i, glint in ipairs(r.glints) do
		local rule = r.rules[i]
		if (rule._alpha or 0) > 0.001 then fail(scenario, ("rule %d is lit while the glint runs it; it should rest at nothing"):format(i)) end
		local a = G.alphaAt(glint, now)
		if a <= 0.5 then
			fail(scenario, ("glint %d is drawn at alpha %.2f 0.10 s into its run, under the frames above it"):format(i, a))
		end
		if glint._parent ~= r.art then fail(scenario, ("glint %d is not a child of the art"):format(i)) end
	end
end)

-- ------------------------------------------------------------------ 6
-- The stripe's sweep slides along the stripe, so Calm does without it; on
-- Full it still plays.
withTree(T .. "Calm drops the light sweep", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass", function(p) p.accentMode = "stripe" p.effects = "calm" end)
	local sweep = r.sweep and r.sweep.anim
	if not (sweep and FT.visible(r.sweep)) then fail(scenario, "SKIPPED -- the stripe's sweep is not up") return end
	local before = plays(sweep)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(sweep) ~= before then fail(scenario, "with Effects on Calm the stripe's sweep still slid for a favour") end
	-- The control: on Full the same favour slides it.
	ns.db.profile.prompt.effects = "full"
	wipe(ns.owed)
	ns.addon:Tick()
	Mock.advance(0.4)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(sweep) ~= before + 1 then fail(scenario, "on Full the stripe's sweep did not slide for a favour") end
end)

-- ------------------------------------------------------------------ 7
-- A repaint about somebody else, or a look from Looks/ applied, mid-entrance:
-- the words at full, every rule at nothing, nothing left drawing.
withTree(T .. "a style change mid-entrance leaves the words lit", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local function wordsLit(what)
		if r.reveal._playing then fail(scenario, what .. " left the words' reveal running") end
		local a = wordsAlpha(r, GetTime())
		if not near(a, 1, 0.001) then fail(scenario, ("%s left the words at alpha %.2f"):format(what, a)) end
		for i, rule in ipairs(r.rules) do
			if rule.draw._playing then fail(scenario, ("%s left rule %d drawing"):format(what, i)) end
			if (rule._alpha or 0) > 0.001 then fail(scenario, ("%s left rule %d lit"):format(what, i)) end
		end
	end
	-- A repaint about somebody else, 0.05 s in.
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	Mock.advance(0.05)
	if not (r.reveal._playing and r.rules[1].draw._playing) then
		fail(scenario, "SKIPPED -- the entrance is not under way 0.05 s in")
		return
	end
	ns.Prompt:StopFlourishes()
	wordsLit("a repaint mid-entrance")
	-- A look from Looks/ applied 0.05 s in.
	Mock.advance(2)
	FT.settle()
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up again") return end
	Mock.advance(0.05)
	if not r.reveal._playing then fail(scenario, "SKIPPED -- the second entrance is not under way") return end
	ns.db.profile.prompt.style = "luxe"
	ns.Prompt:ApplyStyle()
	wordsLit("a look applied mid-entrance")
	if ns.Prompt.state.glintPlaying then fail(scenario, "a look applied left the glints' flag up") end
end)

-- ------------------------------------------------------------------ 8
-- A look's fight dim is the look's own: a flourish in a fight leaves
-- textLayer's alpha exactly where the look put it, on every look that dims
-- its words.
local FIGHT_DIM = { toast = 0.78, ribbon = 0.86, arcane = 0.80 }
withTree(T .. "a look's fight dim survives a flourish", ANNA, function(ns, scenario)
	for _, style in ipairs({ "toast", "ribbon", "arcane" }) do
		local r = upIn(ns, scenario, style)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		ns.addon:Tick()
		FT.settle()
		local want = FIGHT_DIM[style]
		if not near(r.textLayer._alpha, want, 0.01) then
			fail(scenario, ("SKIPPED -- %s did not dim the words to %.2f in the fight: %s"):format(style, want, tostring(r.textLayer._alpha)))
		else
			for pass = 1, 2 do
				Mock.advance(1)
				ns.Prompt:ShowOutcome("cast", "Anna Aim")
				if not near(r.textLayer._alpha, want, 0.01) then
					fail(scenario, ("%s: flourish %d in a fight snapped the words from %.2f to %s"):format(style, pass, want, tostring(r.textLayer._alpha)))
				end
			end
		end
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	end
end)

-- ------------------------------------------------------------------ 9
-- An outcome during the entrance: the words' reveal is let go before the
-- outcome's dip starts, so the dip begins from full and the words end at full.
withTree(T .. "an outcome during the entrance keeps the words", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1)
	FT.settle()
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	Mock.advance(0.12)
	if not r.reveal._playing then fail(scenario, "SKIPPED -- the words were not still arriving 0.12 s in") return end
	local mark = #FT.log
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if r.reveal._playing then fail(scenario, "the outcome left the words' reveal running") end
	local stopAt, dipAt
	for i = mark + 1, #FT.log do
		local e = FT.log[i]
		if e.group == r.reveal and e.what == "stop" and not stopAt then stopAt = i end
		if e.group == r.textLayer.swap and e.what == "play" and not dipAt then dipAt = i end
	end
	if not dipAt then
		fail(scenario, "SKIPPED -- the outcome did not dip the words")
	elseif not stopAt or stopAt > dipAt then
		fail(scenario, "the words' reveal was not let go before the outcome's dip began, so the dip starts from half-lit words")
	end
	Mock.advance(0.25)
	FT.settle()
	local a = wordsAlpha(r, GetTime())
	if not near(a, 1, 0.001) then fail(scenario, ("the words are at alpha %.2f once the dip has run, not full"):format(a)) end
end)

-- ------------------------------------------------------------------ 10
-- The geometry hunt37 and this file share reads a Scale about the origin the
-- animation names: a rule growing about its left end keeps its left edge.
withTree(T .. "hunt37 rectAt honours the origin", {}, function(_, scenario)
	local art = CreateFrame("Frame", nil, UIParent)
	art:SetSize(300, 100)
	art:SetPoint("CENTER")
	local bar = CreateFrame("Frame", nil, art)
	bar:SetSize(100, 4)
	bar:SetPoint("TOPLEFT", art, "TOPLEFT", 20, -2)
	local tex = bar:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints(bar)
	local L0, R0 = FT.span(tex, "x")
	if not (L0 and R0) then fail(scenario, "SKIPPED -- the synthetic bar has no span") return end
	local left = bar:CreateAnimationGroup()
	local a = left:CreateAnimation("Scale")
	a:SetScaleFrom(0.04, 1)
	a:SetScaleTo(1, 1)
	a:SetOrigin("LEFT", 0, 0)
	a:SetDuration(1)
	left:Play()
	local L, B, R, Tp = G.rectAt(tex, art, GetTime())
	if not L then
		fail(scenario, "rectAt gave the bar no rectangle")
	else
		if not near(L, L0, 1e-6) then
			fail(scenario, ("a bar growing about its left end was placed with its left edge at %.2f, not %.2f"):format(L, L0))
		end
		if not near(R - L, (R0 - L0) * 0.04, 1e-6) then
			fail(scenario, ("a bar at scale 0.04 along its length is %.2f wide, not %.2f"):format(R - L, (R0 - L0) * 0.04))
		end
		local B0, T0 = FT.span(tex, "y")
		if not (near(B, B0, 1e-6) and near(Tp, T0, 1e-6)) then fail(scenario, "a scale of 1 across the bar moved its top or bottom") end
	end
	left:Stop()
	-- And about the middle when the animation names no origin, as every ring.
	local mid = bar:CreateAnimationGroup()
	local m = mid:CreateAnimation("Scale")
	m:SetScaleFrom(0.5, 0.5)
	m:SetScaleTo(1, 1)
	m:SetDuration(1)
	mid:Play()
	L, B, R, Tp = G.rectAt(tex, art, GetTime())
	local cx = (L0 + R0) / 2
	if not (L and near(L, cx - (R0 - L0) / 4, 1e-6) and near(R, cx + (R0 - L0) / 4, 1e-6)) then
		fail(scenario, "a scale with no origin named is not about the bar's middle")
	end
	mid:Stop()
end)

-- ------------------------------------------------------------------ 11
-- A look from Looks/ sees none of it: the rise alone on coming up, no glint
-- for a favour.
withTree(T .. "a look from Looks/ sees none of it", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local groups = { reveal = r.reveal, draw1 = r.rules[1].draw, draw2 = r.rules[2].draw,
		glint1 = r.glints[1].run, glint2 = r.glints[2].run }
	local before = {}
	for name, g in pairs(groups) do before[name] = plays(g) end
	local intro = plays(r.intro)
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	if plays(r.intro) ~= intro + 1 then fail(scenario, "Luxe's panel did not come up with the rise") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	for name, g in pairs(groups) do
		if plays(g) ~= before[name] then fail(scenario, "under Luxe the built-in " .. name .. " played") end
	end
	if ns.Prompt.state.glintPlaying then fail(scenario, "under Luxe the glints' flag went up") end
end)

-- ------------------------------------------------------------------ 12
-- Minimal has no panel for the rules to lie on, so it draws them -- and the
-- glint -- at a little over half strength.
withTree(T .. "minimal draws the rules at half strength", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "minimal")
	local before = { plays(r.rules[1].draw), plays(r.rules[2].draw) }
	if not comeUp(ns) then fail(scenario, "SKIPPED -- the panel did not come up") return end
	for i, rule in ipairs(r.rules) do
		if plays(rule.draw) ~= before[i] + 1 then fail(scenario, ("minimal did not draw rule %d"):format(i)) end
		local c = rule.band and rule.band._color
		if not (c and near(c[4], 0.6, 0.001)) then
			fail(scenario, ("minimal draws rule %d at strength %s, not 0.6"):format(i, tostring(c and c[4])))
		end
	end
	Mock.advance(1)
	FT.settle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	for i, glint in ipairs(r.glints) do
		if plays(glint.run) ~= 1 then fail(scenario, ("minimal ran glint %d %d times for one favour"):format(i, plays(glint.run))) end
		local c = glint.band and glint.band._color
		if not (c and near(c[4], 0.54, 0.001)) then
			fail(scenario, ("minimal runs glint %d at strength %s, not 0.54"):format(i, tostring(c and c[4])))
		end
	end
end)
