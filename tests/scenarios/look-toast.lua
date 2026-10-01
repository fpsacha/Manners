-- The Toast look (Looks/Toast.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua already asks of it.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows
-- the wrong thing.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
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

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005)
end

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Toast with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "toast"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isToast(look)
	return look ~= nil and look.band ~= nil and look.ember ~= nil
end

-- The fired colour for a reason colour: Looks/Toast.lua's Enamel, and a
-- warm gold fired deeper (Fired). The jewel and the owed glow wear it.
local function fired(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local function push(v) return math.max(0, math.min(1, l + (v - l) * 1.35)) end
	local er, eg, eb = push(r), push(g), push(b)
	if er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then
		er, eg, eb = er * 0.75, eg * 0.70 * 0.75, eb * 0.75
	end
	return er, eg, eb
end

-- The enamel band's colour: the fired colour darkened (ENAMEL_DARK).
local function enamel(r, g, b)
	local er, eg, eb = fired(r, g, b)
	return er * 0.48, eg * 0.48, eb * 0.48
end

-- Relative luminance, from sRGB.
local function luminance(r, g, b)
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

-- ------------------------------------------------------------------ 1
-- The enamel says why, in each reason's colour, both palettes; the owed glow
-- on it agrees; with the marker off the enamel is neutral.
withTree("Toast carries the reason on the enamel", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			local er, eg, eb = enamel(cr, cg, cb)
			if not sameColour(look.band._color, er, eg, eb) then
				fail(scenario, ("the enamel is not in %s's colour in the %s set"):format(reason, palette))
			end
			local fr, fg, fb = fired(cr, cg, cb)
			if not sameColour(look.glow._color, fr, fg, fb) then
				fail(scenario, ("the enamel's glow is not in %s's colour in the %s set")
					:format(reason, palette))
			end
		end
	end
	-- The owed gold is parted from the gold round it by brightness: fired to
	-- a honey amber, well under the gilding's luminance (about 0.48 at its
	-- face), and still warm -- even where it is lit, as the owed glow lights
	-- the enamel and the jewel wears it. Saturation alone blurred into one
	-- ring at game scale.
	p.reasonPalette = "standard"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local c = look.glow._color
	if not (c and luminance(c[1], c[2], c[3]) < 0.7 * 0.48 and c[1] > c[2] and c[2] > c[3]) then
		fail(scenario, "the owed enamel is not parted from the gold it sits in: "
			.. (c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "no colour"))
	end
	-- The colour-blind set's lemon target stays light where it is fired
	-- bright (the glow, the jewel), as its palette means.
	p.reasonPalette = "colourblind"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("target")
	c = look.glow._color
	if not (c and luminance(c[1], c[2], c[3]) > 0.6) then
		fail(scenario, "the colour-blind target's enamel was fired dark like the owed gold")
	end
	p.reasonPalette = "standard"
	-- "stripe" is "both" here: the enamel is where the reason is.
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("target")
	local tr, tg, tb = enamel(ns.Prompt:AccentColor("target"))
	if not sameColour(look.band._color, tr, tg, tb) then
		fail(scenario, "with the marker on the stripe, the toast's enamel lost the reason")
	end
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("target")
	if sameColour(look.band._color, tr, tg, tb) then
		fail(scenario, "with the marker off the enamel still carries the reason's colour")
	end
	-- The subtitle is warmed towards the reason on a dark panel.
	p.accentMode = "icon"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("asked")
	local asked = r.sub._textColor
	ns.Prompt:PaintAccent("group")
	local group = r.sub._textColor
	if sameColour(asked, group[1], group[2], group[3]) then
		fail(scenario, "the subtitle is the same colour whatever the reason")
	end
end)

-- ------------------------------------------------------------------ 2
-- The rails' glints are for a new favour, never for a new face nor for a
-- repaint of the same one; and never on Calm.
withTree("Toast sparkles only for a new favour", CROWD, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "toast"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local look = ns.Prompt:Regions().look
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	-- Strangers on the panel, one after another: faces, not favours.
	local before = plays(look.sweep)
	for _ = 1, 3 do
		ns.Prompt:Paint({ name = "Brannoc Vale", short = "Brannoc", reason = "nearby",
			buff = ns.ResolveBuff(true) }, 0)
		ns.Prompt:StopAttention()
		ns.Prompt:Paint({ name = "Corwin Ash", short = "Corwin", reason = "group",
			buff = ns.ResolveBuff(true) }, 0)
		ns.Prompt:StopAttention()
	end
	tick(ns)
	if plays(look.sweep) > before then
		fail(scenario, "the rails sparkled for a new face on the panel, not a favour")
	end
	-- A favour: the glints run, down both rails.
	owe(ns, "Anna Aim")
	tick(ns)
	if plays(look.sweep) < before + #look.sweep or #look.sweep < 2 then
		fail(scenario, "a new favour on top and the rails did not catch the light")
	end
	-- The same favour, repainted by the scan: nothing more.
	local once = plays(look.sweep)
	Mock.advance(0.5)
	tick(ns)
	tick(ns)
	if plays(look.sweep) > once then fail(scenario, "the rails sparkled again for the same favour") end
	-- Calm: nothing runs down the rails.
	wipe(ns.owed)
	tick(ns)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local calm = plays(look.sweep)
	owe(ns, "Dagna Moss")
	tick(ns)
	if plays(look.sweep) > calm then fail(scenario, "the rails sparkled on Calm") end
end)

-- ------------------------------------------------------------------ 3
-- The owed pulse breathes a few times and then settles to the dark enamel;
-- on Calm it never loops; with nobody owed it goes.
withTree("Toast's pulse breathes three times and holds", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	if not look.pulse[1]._playing then
		fail(scenario, "somebody owed on top on Full, and the toast does not breathe")
	end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(10)
	local _, loops = FT.playing()
	if look.pulse[1]._playing or #loops > 0 then
		fail(scenario, "the owed pulse still loops after its three breaths")
	end
	if not near(look.glow._alpha, 0) then
		fail(scenario, "after its breaths the enamel is not let go to its dark: " .. tostring(look.glow._alpha))
	end
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "the scan started the spent pulse again") end
	-- Calm: never a loop, the glow held.
	wipe(ns.owed)
	tick(ns)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	_, loops = FT.playing()
	if #loops > 0 then fail(scenario, ("%d animation(s) loop on Calm"):format(#loops)) end
	if not near(look.glow._alpha, 0) then
		fail(scenario, "on Calm the owed glow is not still at the dark enamel")
	end
	-- Nobody owed while it breathes: the glow goes, and the loop with it.
	p.effects = "full"
	wipe(ns.owed)
	tick(ns)
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if not look.pulse[1]._playing then
		fail(scenario, "SKIPPED -- the owed pulse did not start again")
	end
	wipe(ns.owed)
	tick(ns)
	if (look.glow._alpha or 0) > 0 or look.pulse[1]._playing then
		fail(scenario, "the owed glow stayed with nobody owed")
	end
end)

-- ------------------------------------------------------------------ 3b
-- An outcome is about the click, not the favour: a return made while the
-- owed enamel still breathes stops the breathing, and the enamel is the
-- outcome's dark band -- in 1.6's first cut the pulse ran on under the
-- outcome's colour and lit the enamel into a bright green, pale gold or red
-- ring, wider and brighter than the gold beside it.
local OUTCOME = { cast = { 0.52, 0.90, 0.52 }, failed = { 1.00, 0.40, 0.34 }, sent = { 0.91, 0.86, 0.60 } }

withTree("Toast's outcome lets the owed breathing go", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	for _, kind in ipairs({ "cast", "sent", "failed" }) do
		wipe(ns.owed)
		tick(ns)
		owe(ns, "Anna Aim")
		tick(ns)
		if not look.pulse[1]._playing then
			fail(scenario, "SKIPPED -- the owed enamel was not breathing before the " .. kind)
			return
		end
		ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
		-- The scan repaints on under the outcome, while it is on show.
		for _ = 1, 2 do
			Mock.advance(0.2)
			tick(ns)
		end
		if not ns.Prompt:OutcomeLive() then
			fail(scenario, "SKIPPED -- the " .. kind .. " outcome was not on show")
			return
		end
		local o = OUTCOME[kind]
		local dr, dg, db = enamel(o[1], o[2], o[3])
		local band = look.band._color
		if look.pulse[1]._playing or not near(look.glow._alpha or 0, 0) then
			fail(scenario, ("a %s outcome leaves the owed enamel breathing (glow at %s)")
				:format(kind, tostring(look.glow._alpha)))
		end
		if not (band and luminance(band[1], band[2], band[3]) <= luminance(dr, dg, db) + 0.002) then
			fail(scenario, ("a %s outcome lights the enamel past its dark band"):format(kind))
		end
		Mock.advance(10)
		tick(ns)
	end
end)

-- ------------------------------------------------------------------ 4
-- A fight: the gold goes to iron, the icon greys, the text dims; the enamel
-- keeps the reason; the banner holds. And all of it comes back.
withTree("Toast in a fight turns to iron and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local band = look.band._color and { look.band._color[1], look.band._color[2], look.band._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	local rail = look.border[2]
	if not (rail._desaturated and sameColour(rail._color, 0.62, 0.62, 0.64)) then
		fail(scenario, "the gilding did not turn to iron in a fight")
	end
	if not (look.ring._desaturated and look.rim._desaturated and look.chip[1]._desaturated) then
		fail(scenario, "the medallion or the chip kept its gold in a fight")
	end
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	-- Dimmed by its colour, never made see-through: the banner starts at the
	-- medallion's centre, so a see-through icon split down the middle.
	if (r.icon._alpha or 1) < 0.99 then
		fail(scenario, "the icon turned see-through in a fight (alpha " .. tostring(r.icon._alpha) .. ")")
	end
	if not (r.icon._color and r.icon._color[1] < 0.9) then
		fail(scenario, "the icon is not dimmed in a fight")
	end
	-- And an opaque well under it, over the banner's end and the gold, and
	-- still under the icon (ARTWORK 0).
	local well = look.well
	if not (well and well._shown ~= false and (well._color and well._color[4] or 1) > 0.99
		and well._layer == "ARTWORK" and (well._sublevel or 0) < 0
		and (well._sublevel or -99) > (look.ring._sublevel or 0)
		and (well._width or 0) >= (r.icon._width or 99)) then
		fail(scenario, "nothing opaque under the icon: whatever is behind it shows through")
	end
	if not near(r.textLayer._alpha, 0.78) then fail(scenario, "the text does not dim in a fight") end
	if (r.art._alpha or 1) < 0.99 then
		fail(scenario, "art dimmed whole in a fight (" .. tostring(r.art._alpha) .. "), banner and all")
	end
	if not (band and sameColour(look.band._color, band[1], band[2], band[3])) or look.band._desaturated then
		fail(scenario, "the enamel lost the reason's colour in a fight")
	end
	-- Laid out again during the hold (Prompt says so only when it changes):
	-- the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if not rail._desaturated then fail(scenario, "laying the toast out again during the hold put the gold back") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if rail._desaturated or r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's iron stayed on after it ended")
	end
	if r.icon._color and r.icon._color[1] < 0.99 then
		fail(scenario, "the icon stayed dimmed after the fight ended")
	end
	-- Another look finds the icon as it was.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then
		fail(scenario, "leaving Toast during a fight left the icon dimmed on glass")
	end
end)

-- ------------------------------------------------------------------ 5
-- The outcome: the name stays, the second line becomes the verdict with its
-- glyph, and the next paint takes it back.
withTree("Toast writes the verdict on the second line", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named:find("buffed", 1, true) then
		fail(scenario, "a landed buff moved the name on the toast: " .. named)
	end
	if r.sub:GetText() ~= "buffed" or look.glyph._shown == false
		or not tostring(look.glyph._file):find("Check", 1, true) then
		fail(scenario, "a landed buff's second line is not a ticked \"buffed\": " .. tostring(r.sub:GetText()))
	end
	if not sameColour(look.band._color, enamel(0.52, 0.90, 0.52)) then
		fail(scenario, "a landed buff did not turn the enamel green")
	end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." or not tostring(look.glyph._file):find("Cross", 1, true) then
		fail(scenario, "a refusal's second line is not the game's words with a cross: " .. tostring(r.sub:GetText()))
	end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the toast's icon") end
	Mock.advance(2)
	tick(ns)
	if look.glyph._shown ~= false or r.sub:GetText() == "Out of range." then
		fail(scenario, "the verdict stayed on the toast after the outcome ran out")
	end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	local er, eg, eb = enamel(ns.Prompt:AccentColor("owed"))
	if not sameColour(look.band._color, er, eg, eb) then
		fail(scenario, "the enamel kept the outcome's colour after it ran out")
	end
	-- A cast nobody confirmed claims nothing: no flare, no burst.
	local flare, burst = plays(look.flareAnims), look.burstAnim._plays
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.flareAnims) > flare or look.burstAnim._plays > burst then
		fail(scenario, "a cast nobody confirmed got the toast's flourish")
	end
	Mock.advance(2)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(look.flareAnims) == flare or look.burstAnim._plays == burst then
		fail(scenario, "a landed buff did not flare the gilding")
	end
end)

-- ------------------------------------------------------------------ 6
-- The bound key on a chip, the count moved onto the medallion beside it; no
-- chip with no key, none while unlocked; and the name wins.
withTree("Toast shows the bound key on a chip", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	if look.keyChip[2]._shown ~= false or look.keyText._shown ~= false then
		fail(scenario, "a key chip with no key bound")
	end
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	if look.keyChip[2]._shown == false or look.keyText:GetText() ~= "SHIFT-F" then
		fail(scenario, "a key bound to the prompt and no chip naming it: " .. tostring(look.keyText:GetText()))
	end
	-- The count is a chip beside it -- never a coin on the medallion, which
	-- covered the icon (tests/scenarios/readable-toast.lua) -- and the lines
	-- keep the key's room.
	local at = look.chipBox.points[1]
	if look.countMode ~= "pair" or r.count._shown == false or not (at and at[2] == look.keyBox) then
		fail(scenario, "with the key's chip up the count is not beside it: " .. tostring(look.countMode))
	end
	local right = r.name.points[#r.name.points]
	if not (right and right[1] == "RIGHT" and right[2] <= -(look.keyRoom - 0.5)) then
		fail(scenario, "the name runs under the key's chip")
	end
	-- The name wins: a long name at a narrow width and the chip steps aside.
	p.width = 150
	ns.Prompt:ApplyStyle()
	ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
		buff = ns.ResolveBuff(true) }, 0)
	if look.keyChip[2]._shown ~= false then
		fail(scenario, "the key's chip stayed up and cut a name that could not shrink to fit")
	end
	-- Unlocked, a press buffs nobody: no key.
	p.width = 230
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.keyChip[2]._shown ~= false then fail(scenario, "the key's chip shows on an unlocked prompt") end
	p.locked = true
	ns.Prompt:ApplyStyle()
	SetBinding("SHIFT-F", nil)
	tick(ns)
	if look.keyChip[2]._shown ~= false then fail(scenario, "the key's chip outlived the binding") end
	if look.countMode ~= "chip" then fail(scenario, "with no key the count did not go back to its chip") end
end)

-- ------------------------------------------------------------------ 7
-- The favour clock burns down along the bottom rail as the time to return
-- the favour runs out, keeps burning on Calm and in a fight, and goes with
-- the debt.
withTree("Toast's favour clock burns down with the debt", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local full = look.clockLen
	if look.ember._shown == false or not near(look.ember._width, full, 0.5) then
		fail(scenario, ("a favour just done and the clock is not full: %s of %s")
			:format(tostring(look.ember._width), tostring(full)))
	end
	-- Half of the debt's time gone (the scenarios' debts run 100 s).
	Mock.advance(50)
	tick(ns)
	if not near(look.ember._width, full / 2, 1) then
		fail(scenario, ("half the time gone and the clock is at %s of %s")
			:format(tostring(look.ember._width), tostring(full)))
	end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.ember._shown == false then fail(scenario, "the favour clock went on Calm") end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if look.ember._shown == false then fail(scenario, "the favour clock went in a fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	wipe(ns.owed)
	ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "nearby", buff = ns.ResolveBuff(true) }, 0)
	if look.ember._shown ~= false then fail(scenario, "the favour clock stayed with nothing owed") end
end)

-- ------------------------------------------------------------------ 8
-- Small panels get the single rail; the medallion always fits inside the
-- button, so the whole look takes the click and the drag.
withTree("Toast fits its gilding and medallion to the panel", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario, function(pp) pp.height = 36 end)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	if not tostring(look.border[2]._file):find("BorderSlim", 1, true) then
		fail(scenario, "the double rail at height 36, where it turns to mush")
	end
	-- The banner's rails run in under the medallion to its centre, so a
	-- medallion shorter than the banner shows their ends above and below it:
	-- whatever the icon size, it spans the banner.
	local sizes = { { 180, 36, 11, 26 }, { 230, 46, 13, 30 }, { 320, 58, 17, 40 }, { 230, 70, 13, 64 },
		{ 220, 44, 13, 12 }, { 220, 44, 13, 20 }, { 220, 60, 13, 30 }, { 320, 70, 11, 30 }, { 180, 36, 11, 12 } }
	for _, size in ipairs(sizes) do
		p.width, p.height, p.fontSize, p.iconSize = size[1], size[2], size[3], size[4]
		ns.Prompt:ApplyStyle()
		if (look.M or 0) > p.height + 0.01 or look.cx < (look.M or 0) / 2 - 0.01 then
			fail(scenario, ("at %dx%d the medallion (%s) overhangs the button")
				:format(size[1], size[2], tostring(look.M)))
		end
		if (look.M or 0) < p.height - 1.01 then
			fail(scenario, ("at %dx%d with an icon of %d the medallion (%s) is shorter than the banner")
				:format(size[1], size[2], size[4], tostring(look.M)))
		end
		if p.height >= 40 and tostring(look.border[2]._file):find("Slim", 1, true) then
			fail(scenario, "the single rail at height " .. p.height)
		end
	end
	if ns.TwoLineHeight(13, "toast") ~= 38 then
		fail(scenario, "two lines need " .. tostring(ns.TwoLineHeight(13, "toast")) .. " on Toast, not 38")
	end
end)

-- ------------------------------------------------------------------ 9
-- The list's drawer below or above, a gem in each row's reason colour.
withTree("Toast hangs the list in a drawer with gems", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local row = r.rows[1]
	local at = row.points[#row.points]
	if not (look.drawer[7]._shown ~= false and look.drawer[2]._shown == false and at and at[5] < -look.bottom) then
		fail(scenario, "the list below the banner is not in a drawer under it")
	end
	local shown = 0
	for i, gem in ipairs(look.gems) do
		if gem._shown ~= false then
			shown = shown + 1
			if not gem._color then fail(scenario, "gem " .. i .. " has no reason colour") end
		end
	end
	if shown == 0 then fail(scenario, "the list's rows wear no gems") end
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	at = row.points[#row.points]
	if not (look.drawer[2]._shown ~= false and look.drawer[7]._shown == false and at and at[5] > 0) then
		fail(scenario, "the list above the banner is not in a drawer over it")
	end
end)

-- ------------------------------------------------------------------ 10
-- Leaving the toast gives back the room it kept for its lines, so the next
-- look fits them to its own.
withTree("leaving Toast gives the lines their room back", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local kit = look.kit
	if kit.fit.room[r.name] ~= nil or kit.fit.room[r.sub] ~= nil then
		fail(scenario, "glass fits its lines to the room Toast kept")
	end
	if r.icon._mask == look.mask then fail(scenario, "Toast's mask still shapes the icon on glass") end
end)

-- ------------------------------------------------------------------ 11
-- With the second line down there is nowhere below for the verdict, so the
-- name line takes Prompt's headline, which says both what happened and to
-- whom: the second line switched off, and a panel too short for two lines.
withTree("Toast writes the outcome on the name line when the second is down", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showSub = false end)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	for _, setup in ipairs({
		{ "second line off", function() p.showSub, p.height = false, 44 end },
		{ "a panel 36 high", function() p.showSub, p.height = true, 36 end },
	}) do
		setup[2]()
		ns.Prompt:ApplyStyle()
		tick(ns)
		Mock.advance(3)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		local line = tostring(r.name:GetText())
		if r.sub:IsShown() then
			fail(scenario, setup[1] .. ": the second line is up, so this checks nothing")
		elseif not (line:find("could not buff", 1, true) and line:find("Anna Aim", 1, true)) then
			fail(scenario, setup[1] .. ": a refusal wrote only \"" .. line .. "\", not what happened")
		end
		Mock.advance(3)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		line = tostring(r.name:GetText())
		if not (line:find("buffed", 1, true) and line:find("Anna Aim", 1, true)) then
			fail(scenario, setup[1] .. ": a landed buff wrote only \"" .. line .. "\"")
		end
	end
end)

-- ------------------------------------------------------------------ 12
-- A client with no word for the verdict yet keeps the name where it was and
-- takes the built-in second line, which is translated, as the verdict.
withTree("Toast keeps the name on a German client's outcome", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	-- A translation made before the verdict words: they are taken out again,
	-- so this is the path a client without them takes (all eight have them).
	for _, k in ipairs({ "buffed", "sent, unconfirmed", "could not buff" }) do rawset(ns.L, k, nil) end
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local name = tostring(r.name:GetText())
	if name:find("Anna", 1, true) ~= 1 or name:find(ns.L["the game confirmed it"], 1, true) then
		fail(scenario, "a landed buff on a German client rewrote the name line: " .. name)
	end
	if r.sub:GetText() == "buffed" or r.sub:GetText() ~= ns.L["the game confirmed it"] then
		fail(scenario, "a German client's verdict is not the translated second line: " .. tostring(r.sub:GetText()))
	end
	Mock.advance(3)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	name = tostring(r.name:GetText())
	if name:find("Anna", 1, true) ~= 1 then
		fail(scenario, "a sent buff on a German client moved the name: " .. name)
	end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 13
-- With the icon off, as with it on, the count goes on a chip beside the
-- key's, inside the banner, and the lines keep the room of both.
withTree("Toast keeps the count inside the banner with the icon off", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showIcon = false end)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	if look.keyChip[2]._shown == false then fail(scenario, "no key chip with a key bound") end
	if r.count._shown == false or not look.countMode then
		fail(scenario, "the count went with the icon off and a key bound")
	end
	-- Never at the medallion's place: with no medallion that is the panel's
	-- left edge, half off the button.
	local at = look.chipBox.points[1]
	if look.countMode == "coin" or not (at and at[2] == look.keyBox) then
		fail(scenario, "with no medallion the count is not beside the key's chip: " .. tostring(look.countMode))
	end
	local taken = 9 + (look.keyBox._width or 0) + 4 + (look.chipBox._width or 0)
	if taken > p.width then fail(scenario, "the two chips run off the banner") end
	local right = r.name.points[#r.name.points]
	if not (right and right[1] == "RIGHT" and right[2] <= -taken + 0.5) then
		fail(scenario, "the name runs under the count's chip beside the key's")
	end
	-- The key unbound: the count's chip is back at the right.
	SetBinding("SHIFT-F", nil)
	tick(ns)
	if look.countMode ~= "chip" then fail(scenario, "with no key the count did not go back to its chip") end
end)

-- ------------------------------------------------------------------ 14
-- A key bound anew while its chip is up is a chip of another width, and the
-- lines are placed again beside it.
withTree("Toast gives the lines the new key's room", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	SetBinding("F", COMMAND)
	tick(ns)
	local before = look.keyRoom
	SetBinding("F", nil)
	SetBinding("SHIFT-MOUSEWHEELUP", COMMAND)
	tick(ns)
	tick(ns)
	if not (look.keyUp and look.keyRoom and before and look.keyRoom > before) then
		fail(scenario, "SKIPPED -- the longer key did not make a wider chip")
		return
	end
	local room = look.kit.fit.room[r.name]
	if not (room and room <= p.width - look.textX - look.keyRoom + 0.5) then
		fail(scenario, ("the name keeps the old key's room (%s) beside a wider chip (room %d)")
			:format(tostring(room), p.width - look.textX - look.keyRoom))
	end
end)

-- ------------------------------------------------------------------ 15
-- With the icon off, a jewel at the banner's end carries the reason.
withTree("Toast carries the reason on a jewel with the icon off", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showIcon = false end)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local seen = {}
	for _, reason in ipairs({ "target", "group", "nearby" }) do
		ns.Prompt:PaintAccent(reason)
		local c = look.jewel._color
		if look.jewel._shown == false or not c then
			fail(scenario, "no jewel carries the reason with the icon off")
			return
		end
		-- Halfway between the dark enamel and the fired colour: the reason,
		-- with the enamel's restraint.
		local fr, fg, fb = fired(ns.Prompt:AccentColor(reason))
		local dr, dg, db = enamel(ns.Prompt:AccentColor(reason))
		if not sameColour(c, (fr + dr) / 2, (fg + dg) / 2, (fb + db) / 2) then
			fail(scenario, "the jewel is not in " .. reason .. "'s colour")
		end
		seen[#seen + 1] = c[1] + c[2] * 10 + c[3] * 100
	end
	if seen[1] == seen[2] or seen[2] == seen[3] then fail(scenario, "the jewel is one colour whatever the reason") end
	if look.textX < look.jewel.points[1][4] + (look.jewel._width or 0) / 2 then
		fail(scenario, "the name starts on the jewel")
	end
	-- And it is only for a panel with no medallion.
	p.showIcon = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.jewel._shown ~= false then fail(scenario, "the jewel shows beside the medallion") end
end)

-- ------------------------------------------------------------------ 16
-- The favour clock: the spent time as ash its whole length, the time left
-- over it, lighter than the dark enamel, and a bead at its end big enough to
-- see at the game's scale; none of it additive.
withTree("Toast's clock burns over its ash", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	Mock.advance(60)
	tick(ns)
	local ash, ember = look.ash, look.ember
	if not (ash and ash._shown ~= false and near(ash._width, look.clockLen, 0.5)) then
		fail(scenario, "no ash under the clock's spent time")
	elseif (ash._blend or "BLEND") == "ADD" or not (ash._color and ash._color[1] < 0.5) then
		fail(scenario, "the clock's ash is light, not dark")
	end
	if not (ember._width and ember._width < look.clockLen * 0.6) then
		fail(scenario, "the clock did not burn down")
	end
	local band = look.band._color
	local ec = ember._color
	if not (ec and band and luminance(ec[1], ec[2], ec[3]) > luminance(band[1], band[2], band[3]) + 0.05) then
		fail(scenario, "the burning clock is no lighter than the enamel")
	end
	if (look.bead._width or 0) < look.clockH * 2 or (look.bead._height or 0) < look.clockH * 2 then
		fail(scenario, "the clock's spark is too small to see")
	end
	for _, t in ipairs({ ash, ember, look.bead }) do
		if (t._blend or "BLEND") == "ADD" then fail(scenario, "the favour clock is drawn in additive light") end
	end
	wipe(ns.owed)
	ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "nearby", buff = ns.ResolveBuff(true) }, 0)
	if ash._shown ~= false then fail(scenario, "the clock's ash stayed with nothing owed") end
end)

-- ------------------------------------------------------------------ 18
-- The options page says this look sizes the icon from the height, and does
-- not offer a slider the look does not read.
withTree("Toast's icon size is stated on the options page", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local slider = H.findOption(ns.optionsTable, "iconSize")
	local notice = H.findOption(ns.optionsTable, "iconSizeCapped")
	if not (slider and notice) then
		fail(scenario, "SKIPPED -- no icon size options")
		return
	end
	-- A slider value unlike the drawn size, so the notice is seen to name
	-- the one Toast draws (at the default height both are 30).
	p.iconSize = 20
	ns.Prompt:ApplyStyle()
	local drawn = math.floor((look.iconSize or 0) + 0.5)
	if drawn == 20 then fail(scenario, "SKIPPED -- Toast drew the slider's size, so nothing tells them apart") end
	if not slider.disabled() then fail(scenario, "the icon size slider is live on a look that ignores it") end
	if notice.hidden() then fail(scenario, "nothing on the options page says how Toast sizes its icon") end
	local text = tostring(notice.name())
	if not text:find(tostring(drawn), 1, true) then
		fail(scenario, ("the notice does not give the icon's size (%d): %s"):format(drawn, text))
	end
	-- Another look: the slider is back.
	p.style = "glass"
	if slider.disabled() then fail(scenario, "the icon size slider is off on glass") end
end)

-- ------------------------------------------------------------------ 19
-- Every file a look names is one the package ships: a wrong name draws a
-- solid box in the game and throws nothing. Every look with regions of its
-- own, in the states that swap files: round and square, slim and double
-- rail, the icon off, and the outcomes' glyphs.
withTree("every look's art is in the package", ANNA, function(ns, scenario)
	local function onDisk(path)
		local rel = path:match("^Interface\\AddOns\\Manners\\(.+)$")
		if not rel then return true end
		local f = io.open(dir .. "/" .. rel:gsub("\\", "/") .. ".tga", "rb")
		if f then f:close() return true end
		return false
	end
	local missing, checked = {}, 0
	local function walk(look)
		local seen = {}
		local function one(x)
			if type(x) ~= "table" or seen[x] then return end
			seen[x] = true
			if type(x._file) == "string" then
				checked = checked + 1
				if not onDisk(x._file) then missing[x._file] = true end
			end
		end
		for _, x in ipairs(look.own or {}) do one(x) end
		for _, x in pairs(look) do one(x) end
	end
	local looked = 0
	for key in pairs(ns.Looks.list) do
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style = key
		for _, setup in ipairs({
			function() p.roundIcon, p.height, p.showIcon = false, 44, true end,
			function() p.roundIcon, p.height = true, 36 end,
			function() p.showIcon = false end,
		}) do
			setup()
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			tick(ns)
			local look = ns.Prompt:Regions().look
			if look and look.own then
				looked = looked + 1
				walk(look)
				for _, kind in ipairs({ "cast", "failed", "sent" }) do
					Mock.advance(3)
					ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
					walk(look)
				end
			end
			Mock.advance(3)
			tick(ns)
		end
	end
	if looked == 0 or checked == 0 then fail(scenario, "no look's art was checked") end
	for file in pairs(missing) do
		fail(scenario, "a look draws " .. file .. ", which the package does not ship")
	end
end)

-- ------------------------------------------------------------------ 20
-- No additive light at rest. tools/render_prompt.py draws ADD far more
-- gently than the client does, and 1.5.1's toast, tuned against it, wore a
-- bright glow ring and a glaring rim in the game. So once the panel has
-- settled -- no flourish playing -- no Toast texture on screen is ADD with
-- any alpha, in any state it can rest in; and each flourish that is ADD
-- (the rails' glints, the ring of light, the flare, the burst) is a one-shot
-- of 0.6 s at most, so it has gone out by the time the panel is at rest.
local FLOURISH = 0.6

-- The Toast textures drawn additively with some alpha, or with a group still
-- playing on them, as "file (why)" strings.
local function additiveLit(look)
	local lit = {}
	for _, t in ipairs(look.own or {}) do
		if t._blend == "ADD" and FT.visible(t) then
			local a, x = 1, t
			while x do
				a = a * (x._alpha or 1)
				x = x._parent
			end
			a = a * (t._color and t._color[4] or 1)
			local playing = false
			for _, g in ipairs(t._groups or {}) do
				if g._playing then playing = true end
			end
			if a > 0.001 or playing then
				lit[#lit + 1] = ("%s (%s)"):format(tostring(t._file):match("[^\\]+$") or "?",
					playing and "still animating" or ("alpha %.2f"):format(a))
			end
		end
	end
	return lit
end

withTree("Toast keeps no additive light at rest", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	-- Every flourish is a short one-shot.
	local groups = 0
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" then
			for _, g in ipairs(t._groups or {}) do
				groups = groups + 1
				if g._looping and g._looping ~= "NONE" then
					fail(scenario, ("an additive light loops: %s"):format(tostring(t._file)))
				elseif FT.groupLength(g) > FLOURISH + 1e-6 then
					fail(scenario, ("an additive flourish lasts %.2f s, more than %.1f: %s")
						:format(FT.groupLength(g), FLOURISH, tostring(t._file)))
				end
			end
		end
	end
	if groups == 0 then fail(scenario, "SKIPPED -- the toast has no additive flourish to judge") end

	-- The plays asked of every group on an additive texture.
	local function additivePlays()
		local n = 0
		for _, t in ipairs(look.own) do
			if t._blend == "ADD" then
				for _, g in ipairs(t._groups or {}) do n = n + (g._plays or 0) end
			end
		end
		return n
	end

	local function check(what)
		-- The scan repaints several times a second with nothing changed; a
		-- flourish started again on each is lasting additive light.
		local before = additivePlays()
		for _ = 1, 3 do
			ns.addon:Tick()
			Mock.advance(0.3)
		end
		if additivePlays() > before then
			fail(scenario, ("%s: an additive flourish replays on a repaint"):format(what))
		end
		Mock.advance(FLOURISH + 0.01)
		FT.settle()
		local lit = additiveLit(look)
		if #lit > 0 then
			fail(scenario, ("%s: additive light at rest: %s"):format(what, table.concat(lit, ", ")))
		end
	end

	-- A new favour on Full lights its flourishes (else this checks nothing).
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local _, loops = FT.playing()
	local playing = 0
	for _, g in ipairs(FT.playing()) do
		local owner = g._owner
		if owner and owner._blend == "ADD" then playing = playing + 1 end
	end
	if playing == 0 then fail(scenario, "SKIPPED -- a new favour lit no flourish") end
	check("a new favour, owed and breathing")
	if #loops == 0 then fail(scenario, "SKIPPED -- the owed pulse is not breathing") end
	Mock.runTimers(10)
	check("owed, after its breaths")

	-- The cursor on it.
	local button = ns.Prompt:GetButton()
	if button.scripts.OnEnter then button.scripts.OnEnter(button) else look:Hover(true) end
	check("under the cursor")
	if button.scripts.OnLeave then button.scripts.OnLeave(button) else look:Hover(false) end
	check("the cursor gone")

	-- The outcomes, on Full and held on Calm.
	for _, effects in ipairs({ "full", "calm" }) do
		p.effects = effects
		ns.Prompt:ApplyStyle()
		tick(ns)
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			check(("a %s outcome on %s"):format(kind, effects))
		end
		Mock.advance(3)
		tick(ns)
		check("owed on " .. effects)
	end
	p.effects = "full"

	-- A fight.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	check("in a fight")
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)

	-- Every setting that changes what is drawn.
	SetBinding("SHIFT-F", COMMAND)
	for _, setup in ipairs({
		{ "the list shown", function() p.showQueue, p.queueRows = true, 3 end },
		{ "a round icon", function() p.roundIcon = true end },
		{ "the icon off", function() p.showIcon = false end },
		{ "180x36", function() p.showIcon, p.width, p.height, p.fontSize = true, 180, 36, 11 end },
		{ "360x120", function() p.width, p.height, p.fontSize = 360, 120, 24 end },
		{ "a light panel", function() p.width, p.height, p.fontSize, p.bgColor = 220, 44, 13, { 0.85, 0.82, 0.74, 1 } end },
	}) do
		setup[2]()
		ns.Prompt:ApplyStyle()
		wipe(ns.owed)
		tick(ns)
		owe(ns, "Anna Aim")
		tick(ns)
		check(setup[1])
		Mock.runTimers(10)
		check(setup[1] .. ", after the breaths")
	end
	SetBinding("SHIFT-F", nil)
	if r.icon._shown == false and look.medallion._shown ~= false then
		fail(scenario, "SKIPPED -- the prompt did not come back")
	end
end)
