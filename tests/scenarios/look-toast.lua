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

-- The enamel's colour for a reason colour: Looks/Toast.lua's Enamel.
local function enamel(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local function push(v) return math.max(0, math.min(1, l + (v - l) * 1.35)) end
	return push(r), push(g), push(b)
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

-- ------------------------------------------------------------------ 1
-- The enamel says why, in each reason's colour, both palettes; the light
-- behind the medallion agrees; with the marker off the enamel is neutral.
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
			if not sameColour(look.bloom._color, cr, cg, cb) then
				fail(scenario, ("the light behind the medallion is not in %s's colour in the %s set")
					:format(reason, palette))
			end
		end
	end
	-- The owed gold is pushed off the gold round it: more saturated than the
	-- palette's own.
	p.reasonPalette = "standard"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local c = look.band._color
	local owed = { ns.Prompt:AccentColor("owed") }
	if not (c and c[1] - c[3] > (owed[1] - owed[3]) + 0.05) then
		fail(scenario, "the owed enamel is no more saturated than the gold it sits in")
	end
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
-- The rails' sparks, the streak and the twinkle are for a new favour, never
-- for a new face nor for a repaint of the same one; and never on Calm.
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
	local before = plays(look.sweep) + look.streakAnim._plays + look.twinkleAnim._plays
	for _ = 1, 3 do
		ns.Prompt:Paint({ name = "Brannoc Vale", short = "Brannoc", reason = "nearby",
			buff = ns.ResolveBuff(true) }, 0)
		ns.Prompt:StopAttention()
		ns.Prompt:Paint({ name = "Corwin Ash", short = "Corwin", reason = "group",
			buff = ns.ResolveBuff(true) }, 0)
		ns.Prompt:StopAttention()
	end
	tick(ns)
	if plays(look.sweep) + look.streakAnim._plays + look.twinkleAnim._plays > before then
		fail(scenario, "the rails sparkled for a new face on the panel, not a favour")
	end
	-- A favour: the sparks run, all three kinds.
	owe(ns, "Anna Aim")
	tick(ns)
	if plays(look.sweep) == before or look.streakAnim._plays == 0 or look.twinkleAnim._plays == 0 then
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
-- The owed pulse breathes a few times and then holds still; on Calm it never
-- loops; with nobody owed it goes.
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
	if not near(look.bloomPulse._alpha, 0.45) then
		fail(scenario, "after its breaths the owed glow is not held still: " .. tostring(look.bloomPulse._alpha))
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
	if not near(look.bloomPulse._alpha, 0.45) then
		fail(scenario, "on Calm the owed glow is not held still at 0.45")
	end
	-- Nobody owed: the glow goes.
	wipe(ns.owed)
	tick(ns)
	if (look.bloomPulse._alpha or 0) > 0 then fail(scenario, "the owed glow stayed with nobody owed") end
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
	if not (look.ring._desaturated and look.chip[1]._desaturated) then
		fail(scenario, "the medallion or the chip kept its gold in a fight")
	end
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
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
	-- The count, beside it, is a coin on the medallion, and the lines keep
	-- the key's room.
	if look.countMode ~= "coin" or r.count._shown == false then
		fail(scenario, "with the key's chip up the count is not on the medallion: " .. tostring(look.countMode))
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
	for _, size in ipairs({ { 180, 36, 11, 26 }, { 230, 46, 13, 30 }, { 320, 58, 17, 40 }, { 230, 70, 13, 64 } }) do
		p.width, p.height, p.fontSize, p.iconSize = size[1], size[2], size[3], size[4]
		ns.Prompt:ApplyStyle()
		if (look.medallion._width or 0) > p.height + 0.01 or look.cx < (look.medallion._width or 0) / 2 - 0.01 then
			fail(scenario, ("at %dx%d the medallion (%s) overhangs the button")
				:format(size[1], size[2], tostring(look.medallion._width)))
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
