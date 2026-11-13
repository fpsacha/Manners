-- The built-in looks' material: the glass as a pane of enchanted glass with
-- the light on it, the framed look as the classic tooltip's rim, the icon in
-- a chamfered metal bezel that carries the reason colour and lifts lighter
-- under the cursor (Prompt/Panel.lua, tools/make_panel_textures.py).
--
-- What these hold the prompt to:
--   * the glass shows nine pane pieces and nine of light and none of the
--     sheen, hairlines or bevel it wore before; the framed look a flat panel,
--     nine rim pieces and, when the marker asks, the stripe as an inlay inside
--     the rim; minimal none of those and still the bezel;
--   * the bezel follows the icon's shape, wears the reason colour (or a neutral
--     metal), is drawn at iconSize / BEZEL_FRAME and never taller than the
--     panel, and sorts above the pane's light and the rim on the same frame;
--   * the cursor fades its lighter twin up in 0.12 s, holds it there for as
--     long as the cursor stays (the owed amber, the colour hovered most, must
--     visibly change), and lets go in 0.18 s to nothing, from wherever the
--     fade had got to, and never on a look from Looks/;
--   * a refusal paints the bezel red and the next paint of a person restores
--     the reason colour;
--   * the text's ink is judged against the pane as drawn;
--   * every file the panel names ships, the generator draws the same bytes
--     twice and the bytes that ship, the pane and the rim stay under their
--     caps, the bezels are grey, the light leaves the middle cell (under the
--     words) empty, and the top-left corner pools the light along the cut
--     instead of showing a speck;
--   * the pane reads as a thick slab of cut glass struck from the upper left:
--     the polished cut, a dark gap a unit wide, a refraction line a unit wide
--     3 units in, cool white along the top and left (falling away round the
--     slab), a darker line in its place along the bottom and right, a fill
--     light on the cut there, and a faint glow under the top line that is
--     gone 6 units in, long before the words;
--   * the slab's light is drawn white at exactly 0.9 x the player's opacity,
--     on any panel colour, laid on the pane's own corners, and the pane's top
--     keeps the player's colour and opacity exactly.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree
local MC = dofile(dir .. "/tests/materials_check.lua")

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local BUILTIN = { "glass", "framed", "minimal" }
-- The figures the panel's material is drawn to (tools/make_panel_textures.py,
-- Prompt/Prompt.lua and Prompt/Text.lua, which must agree).
local BEZEL_FRAME = 0.75
local PANE_EDGE, PANE_MID = 0.60, 0.78
local NEUTRAL = { 0.42, 0.42, 0.46 }
local REFUSAL_RED = { 0.80, 0.26, 0.22 }
local WORLD_GREY = 0.15
local FILES = { "GlassPane", "GlassLight", "IconBezel", "IconBezelRound", "TooltipRim" }
local GENERATOR = "tools/make_panel_textures.py"
local python = os.getenv("MANNERS_PYTHON") or "python"

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

local function luma601(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function sameColour(c, r, g, b)
	return type(c) == "table" and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

-- The prompt in `style` with Anna owed on top, after `edit` to the settings.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = style
	p.effects = "full"
	p.showIcon = true
	p.roundIcon = false
	p.accentMode = "icon"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	FT.settle()
	return ns.Prompt:Regions(), p
end

local function shown(r) return r ~= nil and FT.visible(r) end

local function allShown(list, want)
	if type(list) ~= "table" or #list ~= 9 then return false end
	for _, t in ipairs(list) do
		if shown(t) ~= want then return false end
	end
	return true
end

-- Relative luminance, as Prompt/Text.lua works it out.
local function linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(r, g, b)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end
local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- The texel (x, y) of a TGA read by MC.readTGA: r, g, b, a in 0..1. Rows are
-- stored bottom-up, which the symmetric reads here do not mind.
local function texel(tga, x, y)
	local at = tga.offset + (y * tga.w + x) * 4
	local bb, gg, rr, aa = tga.data:byte(at + 1, at + 4)
	return rr / 255, gg / 255, bb / 255, aa / 255
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- A folder nobody else is writing into (hunt35-effects.lua says why the
-- clock alone does not tell the parallel runs apart).
local function tempDir(tag)
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-panel-" .. token .. "-" .. tostring(os.time()) .. "-" .. tag
end

-- Runs the generator into `out`; returns what it printed, or nil when python
-- itself could not run.
local function generate(out)
	local log = out .. ".log"
	os.execute(python .. ' "' .. dir .. "/" .. GENERATOR .. '" --out "' .. out .. '" > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	return text
end

local function removeAll(out)
	for _, name in ipairs(FILES) do os.remove(out .. "/" .. name .. ".tga") end
end

-- ------------------------------------------------------------------ 1
-- What each built-in look is made of.
withTree("panel-material: the glass is a pane with its light, the framed look a rim, minimal neither", ANNA,
	function(ns, scenario)
	for _, style in ipairs(BUILTIN) do
		local r = upIn(ns, scenario, style)
		local glass, framed = style == "glass", style == "framed"
		if not allShown(r.pane, glass) then
			fail(scenario, style .. ": the nine pane pieces are not " .. (glass and "shown" or "hidden"))
		end
		if not allShown(r.glassLight, glass) then
			fail(scenario, style .. ": the nine pieces of light are not " .. (glass and "shown" or "hidden"))
		end
		if not allShown(r.tooltipRim, framed) then
			fail(scenario, style .. ": the nine rim pieces are not " .. (framed and "shown" or "hidden"))
		end
		if shown(r.panel) ~= framed then
			fail(scenario, style .. ": the flat panel is " .. (shown(r.panel) and "shown" or "hidden"))
		end
		if r.sheen or r.hairTop or r.hairBottom or r.bevel or r.iconBack or r.iconEdge then
			fail(scenario, style .. ": a region of the old glass (sheen, hairline, bevel or ring) is still handed out")
		end
		for _, edge in ipairs(r.edges or {}) do
			if shown(edge) then fail(scenario, style .. ": one of the four old edges is drawn") break end
		end
		if not shown(r.bezel) then fail(scenario, style .. ": the bezel is not shown round the icon") end
		if glass and not tostring(r.pane[5]._file):find("GlassPane", 1, true) then
			fail(scenario, "the pane is not the glass art: " .. tostring(r.pane[5]._file))
		end
		if glass and not tostring(r.glassLight[5]._file):find("GlassLight", 1, true) then
			fail(scenario, "the light is not the glass's light: " .. tostring(r.glassLight[5]._file))
		end
		if glass and r.glassLight[5]._blend ~= "BLEND" then
			fail(scenario, "the glass's light is drawn " .. tostring(r.glassLight[5]._blend) .. ", not BLEND")
		end
		if framed and not tostring(r.tooltipRim[5]._file):find("TooltipRim", 1, true) then
			fail(scenario, "the rim is not the tooltip's rail: " .. tostring(r.tooltipRim[5]._file))
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- The framed look carries the stripe, as an inlay inside its rim.
withTree("panel-material: framed carries the stripe", ANNA, function(ns, scenario)
	for _, style in ipairs(BUILTIN) do
		for _, mode in ipairs({ "stripe", "both" }) do
			local r = upIn(ns, scenario, style, function(p) p.accentMode = mode end)
			if not (shown(r.accentTop) and shown(r.accentBottom)) then
				fail(scenario, ("%s with the marker on %s draws no stripe"):format(style, mode))
			end
			if not shown(r.sweep) then
				fail(scenario, ("%s with the marker on %s has no stripe to sweep"):format(style, mode))
			end
			local point = r.accentTop.points and r.accentTop.points[#r.accentTop.points]
			local x = point and point[#point - 1] or 0
			local want = style == "framed" and 3 or 0
			if not near(x, want, 0.01) then
				fail(scenario, ("%s puts the stripe %s units in, not %d"):format(style, tostring(x), want))
			end
		end
		local r = upIn(ns, scenario, style, function(p) p.accentMode = "icon" end)
		if shown(r.accentTop) then fail(scenario, style .. " draws a stripe with the marker on the icon") end
	end
end)

-- ------------------------------------------------------------------ 3
-- The bezel wears the reason colour where the marker asks, a neutral metal
-- otherwise, and the icon's shape.
withTree("panel-material: the bezel wears the reason colour and the icon's shape", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "glass")
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, mode in ipairs({ "icon", "both", "stripe", "off" }) do
			p.accentMode = mode
			ns.Prompt:ApplyStyle()
			for _, reason in ipairs({ "target", "owed", "group", "nearby", "asked", "self" }) do
				ns.Prompt:PaintAccent(reason)
				local wr, wg, wb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]
				if mode == "icon" or mode == "both" then wr, wg, wb = ns.Prompt:AccentColor(reason) end
				if not sameColour(r.bezel._color, wr, wg, wb) then
					fail(scenario, ("%s/%s/%s: the bezel is not %s"):format(palette, mode, reason,
						(mode == "icon" or mode == "both") and "the reason colour" or "the neutral metal"))
				end
				-- The twin is the bezel's own colour lifted toward white, and the
				-- lift shows in luma: the owed amber (the case hovered most) by
				-- at least 0.09, any other by a good part of what room there is
				-- (a near-white one has little).
				local hc = r.bezelHover._color
				if type(hc) ~= "table" then
					fail(scenario, ("%s/%s/%s: the bezel's lift has no colour"):format(palette, mode, reason))
				else
					local lift = luma601(hc[1], hc[2], hc[3]) - luma601(wr, wg, wb)
					local room = 1 - luma601(wr, wg, wb)
					local owedLit = reason == "owed" and (mode == "icon" or mode == "both")
					local need = owedLit and 0.09 or math.min(0.03, 0.3 * room)
					if lift < need or hc[1] < wr - 0.005 or hc[2] < wg - 0.005 or hc[3] < wb - 0.005 then
						fail(scenario, ("%s/%s/%s: the bezel's lift is not lighter than its colour (%.3f in luma)"):format(
							palette, mode, reason, lift))
					end
				end
			end
		end
	end
	p.reasonPalette, p.accentMode = "standard", "icon"
	for _, round in ipairs({ false, true }) do
		p.roundIcon = round
		ns.Prompt:ApplyStyle()
		local file = tostring(r.bezel._file)
		local isRound = file:find("IconBezelRound", 1, true) ~= nil
		if isRound ~= round then
			fail(scenario, ("with the icon %s the bezel is %s"):format(round and "round" or "square", file))
		end
		if tostring(r.bezelHover._file) ~= file then fail(scenario, "the bezel's gold wears another shape") end
		if not shown(r.bezel) then fail(scenario, "the bezel is not shown round a " .. (round and "round" or "square") .. " icon") end
	end
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	if shown(r.bezel) or shown(r.bezelHover) then fail(scenario, "the bezel is drawn with the icon hidden") end
end)

-- ------------------------------------------------------------------ 4
-- The bezel is drawn at iconSize / BEZEL_FRAME, and never taller than the
-- panel.
withTree("panel-material: the bezel fits the panel at the largest icon", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "glass")
	if not near(r.bezel._width, p.iconSize / BEZEL_FRAME, 0.01) or not near(r.bezel._height, r.bezel._width, 0.01) then
		fail(scenario, ("at defaults the bezel is %s by %s, not %.1f"):format(tostring(r.bezel._width),
			tostring(r.bezel._height), p.iconSize / BEZEL_FRAME))
	end
	for _, case in ipairs({ { 220, 44, 36 }, { 320, 72, 64 }, { 80, 20, 12 } }) do
		p.width, p.height, p.iconSize = case[1], case[2], case[3]
		ns.ClampSettings()
		ns.Prompt:ApplyStyle()
		local want = math.min(p.iconSize / BEZEL_FRAME, p.height - 1)
		if not near(r.bezel._width, want, 0.01) then
			fail(scenario, ("at %dx%d with the icon %d the bezel is %s wide, not %.1f"):format(p.width, p.height,
				p.iconSize, tostring(r.bezel._width), want))
		end
		if (r.bezel._height or 0) > p.height - 1 + 0.001 then
			fail(scenario, ("at %dx%d the bezel is %s tall, past the panel"):format(p.width, p.height, tostring(r.bezel._height)))
		end
		if not near(r.bezelHover._width, r.bezel._width, 0.01) then fail(scenario, "the bezel's gold is another size") end
	end
end)

-- ------------------------------------------------------------------ 5
-- The bezel sorts above the pane's light and the framed look's rim on the
-- same frame, and under the icon.
withTree("panel-material: the bezel sits over the hairline and the rim", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local layers = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
	local function order(t) return (layers[t._layer] or 0) * 100 + (t._sublevel or 0) end
	for _, piece in ipairs({ r.glassLight[1], r.glassLight[5], r.tooltipRim[1], r.tooltipRim[5] }) do
		if piece._parent ~= r.bezel._parent then fail(scenario, "the bezel and the panel's material are on different frames") end
		if order(piece) >= order(r.bezel) then
			fail(scenario, ("the bezel (%s %s) does not sort above a piece of the material (%s %s)"):format(
				tostring(r.bezel._layer), tostring(r.bezel._sublevel), tostring(piece._layer), tostring(piece._sublevel)))
		end
	end
	if order(r.bezelHover) <= order(r.bezel) then fail(scenario, "the bezel's gold is not drawn over the bezel") end
	if order(r.icon) <= order(r.bezelHover) then fail(scenario, "the icon does not draw over the bezel") end
	if r.bezel._layer ~= "BORDER" or r.bezel._sublevel ~= 4 then
		fail(scenario, ("the bezel is on %s %s, not BORDER 4"):format(tostring(r.bezel._layer), tostring(r.bezel._sublevel)))
	end
end)

-- ------------------------------------------------------------------ 6
-- The cursor: the gold fades up in 0.12 s and lets go in 0.18 s to nothing;
-- a look from Looks/ gets its own Hover and the bezel's gold stays dark.
withTree("panel-material: hover leaves in 0.18 s", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local hover = r.bezelHover
	local b = ns.Prompt:GetButton()
	if not (hover and hover.enter and hover.leave) then
		fail(scenario, "the bezel's gold has no enter and leave")
		return
	end
	-- The drive to this point may have moved the cursor over the prompt
	-- already: let it go, so what counts is what the moves below add.
	b.scripts.OnLeave(b)
	Mock.advance(0.2)
	FT.settle()
	if (hover._alpha or 0) ~= 0 then fail(scenario, "the gold is lit before the cursor arrives") end
	local e0, l0 = hover.enter._plays, hover.leave._plays
	b.scripts.OnEnter(b)
	if hover.enter._plays ~= e0 + 1 or hover.leave._plays ~= l0 then
		fail(scenario, ("the cursor arriving played enter %d times and leave %d"):format(hover.enter._plays - e0,
			hover.leave._plays - l0))
	end
	local up = hover.enter._anims[1]
	if not (up and near(up._duration, 0.12, 0.001) and up._toAlpha == 1) then
		fail(scenario, "the gold does not fade up to 1 in 0.12 s")
	end
	if not near(FT.groupLength(hover.enter), 0.12, 0.001) then fail(scenario, "the enter is not 0.12 s long") end
	Mock.advance(0.2)
	FT.settle()
	-- The enter holds at full: the client keeps no animation's last alpha, so
	-- the group's end has to leave the texture at 1 for as long as the cursor
	-- stays.
	if hover._alpha ~= 1 then
		fail(scenario, "the gold does not stay at full once it has faded up: " .. tostring(hover._alpha))
	end
	-- And the tooltip or Shift asking again with the cursor still there
	-- neither restarts the fade nor blinks it.
	local ep = hover.enter._plays
	b.scripts.OnEnter(b)
	Mock.advance(0.05)
	FT.settle()
	if hover.enter._plays ~= ep or hover._alpha ~= 1 then
		fail(scenario, "a repeated arrival restarted the fade of the gold")
	end
	b.scripts.OnLeave(b)
	if hover.leave._plays ~= l0 + 1 then fail(scenario, "the cursor leaving did not play the leave") end
	local down = hover.leave._anims[1]
	if not (down and near(down._duration, 0.18, 0.001) and down._toAlpha == 0) then
		fail(scenario, "the gold does not fade to nothing in 0.18 s")
	end
	if not near(FT.groupLength(hover.leave), 0.18, 0.001) then fail(scenario, "the leave is not 0.18 s long") end
	Mock.advance(0.2)
	FT.settle()
	if (hover._alpha or 0) ~= 0 then fail(scenario, "the gold is not parked at nothing after the cursor leaves") end
	-- The leave stopped early parks it too.
	b.scripts.OnEnter(b)
	b.scripts.OnLeave(b)
	hover.leave:Stop()
	if (hover._alpha or 0) ~= 0 then fail(scenario, "a leave stopped early left the gold lit") end
	-- And a look of its own never sees it.
	local p = ns.db.profile.prompt
	p.style = "luxe"
	ns.Prompt:ApplyStyle()
	local before = hover.enter._plays
	b.scripts.OnEnter(b)
	b.scripts.OnLeave(b)
	if hover.enter._plays ~= before then fail(scenario, "the bezel's gold played under a look from Looks/") end
	if (hover._alpha or 0) ~= 0 then fail(scenario, "the bezel's gold is lit under a look from Looks/") end
end)

-- A cursor that leaves part way up lets go from where the gold had got to,
-- and one that comes back lifts it from there.
withTree("panel-material: hover leaves mid-enter from where it got", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local hover = r.bezelHover
	local b = ns.Prompt:GetButton()
	b.scripts.OnLeave(b)
	Mock.advance(0.2)
	FT.settle()
	b.scripts.OnEnter(b)
	Mock.advance(0.06)
	b.scripts.OnLeave(b)
	local from = hover.leave.fade._fromAlpha
	if not (from and from > 0.3 and from < 0.7) then
		fail(scenario, "the cursor leaving half way up let go from " .. tostring(from) .. ", not from about 0.5")
	end
	if not near(hover._alpha, from, 0.001) then
		fail(scenario, "the gold is not left where the cursor found it when it left part way")
	end
	Mock.advance(0.05)
	b.scripts.OnEnter(b)
	local back = hover.enter.fade._fromAlpha
	if not (back and back < from and back > 0) then
		fail(scenario, "the cursor coming back part way lifted the gold from " .. tostring(back) .. ", not from where it had got")
	end
end)

-- A look from Looks/ takes the lift away, and the next arrival on the built-in
-- look lifts it again.
withTree("panel-material: hover lifts again after a look from Looks/", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local hover = r.bezelHover
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	Mock.advance(0.2)
	FT.settle()
	local p = ns.db.profile.prompt
	p.style = "luxe"
	ns.Prompt:ApplyStyle()
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	-- The cursor never left: the next scan's tooltip asks again.
	local before = hover.enter._plays
	b.scripts.OnEnter(b)
	if hover.enter._plays ~= before + 1 then
		fail(scenario, "the cursor still on the panel after a look from Looks/ came and went did not lift the gold again")
	end
end)

-- ------------------------------------------------------------------ 7
-- A refusal paints the bezel red; the next paint of a person restores it.
withTree("panel-material: a refusal paints the bezel red and the next paint restores it", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local ar, ag, ab = ns.Prompt:AccentColor("owed")
	if not sameColour(r.bezel._color, ar, ag, ab) then
		fail(scenario, "SKIPPED -- the bezel is not in the owed colour before the refusal")
		return
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not sameColour(r.bezel._color, REFUSAL_RED[1], REFUSAL_RED[2], REFUSAL_RED[3]) then
		fail(scenario, "the refusal did not turn the bezel red")
	end
	Mock.advance(1)
	ns.addon:Tick()
	if not sameColour(r.bezel._color, ar, ag, ab) then
		fail(scenario, "the bezel stayed red after the refusal was over")
	end
	-- With the marker off the icon, the bezel is neutral and a refusal leaves
	-- it so: the red words and wash say it.
	local p = ns.db.profile.prompt
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not sameColour(r.bezel._color, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]) then
		fail(scenario, "a refusal coloured a bezel that carries no colour")
	end
end)

-- ------------------------------------------------------------------ 8
-- The ink is judged against the pane as drawn under the words: PANE_MID times
-- the panel's two ends (the pane's middle cell, whose grey the shipped file
-- is held to here), on the glass only.
withTree("panel-material: ink is judged on the pane", ANNA, function(ns, scenario)
	local tga = MC.readTGA(dir .. "/Textures/GlassPane.tga")
	if not tga then
		fail(scenario, "SKIPPED -- Textures/GlassPane.tga is not a 32-bit TGA")
		return
	end
	local er = texel(tga, 3, 64)
	local mr = texel(tga, 64, 64)
	if not near(er, PANE_EDGE, 0.03) or not near(mr, PANE_MID, 0.03) then
		fail(scenario, ("the pane's edge is %.3f and its middle %.3f, not %.2f and %.2f"):format(er, mr, PANE_EDGE, PANE_MID))
	end
	local ink = ns.Prompt.lib.ink
	local function over(c, k, ba) return c * k * ba + WORLD_GREY * (1 - ba) end
	local function ends(br, bg, bb, ba, pane)
		return luminance(over(br, 0.62 * pane, ba), over(bg, 0.62 * pane, ba), over(bb, 0.72 * pane, ba)),
			luminance(over(br, pane, ba), over(bg, pane, ba), over(bb, pane, ba))
	end
	for _, colour in ipairs({ { 0.04, 0.04, 0.06, 0.88 }, { 1, 1, 1, 1 }, { 0.2, 0.3, 0.6, 0.7 } }) do
		for _, style in ipairs({ "glass", "framed" }) do
			local r, p = upIn(ns, scenario, style, function(q) q.bgColor = { colour[1], colour[2], colour[3], colour[4] } end)
			-- The words sit on the pane's middle cell, PANE_MID as the file
			-- states it (the texel above holds the file to it within its hair
			-- of noise); the framed look's panel is the bare colour.
			local pane = style == "glass" and PANE_MID or 1
			local wantLo, wantHi = ends(colour[1], colour[2], colour[3], colour[4], pane)
			if not near(ink.lo, wantLo, 0.01) or not near(ink.hi, wantHi, 0.01) then
				fail(scenario, ("%s on (%.2f, %.2f, %.2f, %.2f): the ink's ground is %.3f..%.3f, the %s is %.3f..%.3f")
					:format(style, colour[1], colour[2], colour[3], colour[4], ink.lo, ink.hi,
						style == "glass" and "pane" or "panel", wantLo, wantHi))
			end
			-- The reason line reads on the pane's own bottom as well as it can:
			-- 4.5:1, or the best the ink's own direction (white on a dark panel,
			-- black on a pale one) can reach where even that falls short.
			local c = r.sub._textColor
			if c then
				local have = ratio(luminance(c[1], c[2], c[3]), wantLo)
				local best = math.min(4.5, ratio(ink.light and 1 or 0, wantLo))
				if have < best - 0.05 then
					fail(scenario, ("%s on (%.2f, %.2f, %.2f): the reason line reads at %.2f:1 on the %s's bottom, under %.2f")
						:format(style, colour[1], colour[2], colour[3], have, style == "glass" and "pane" or "panel", best))
				end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 9
-- Every file the panel names ships, a power of two a side.
withTree("panel-material: every texture path the panel names is on disk", ANNA, function(ns, scenario)
	local lib = ns.Prompt.lib
	for _, key in ipairs({ "GLASS_PANE", "GLASS_LIGHT", "BEZEL", "BEZEL_ROUND", "TOOLTIP_RIM" }) do
		local path = lib[key]
		if type(path) ~= "string" then
			fail(scenario, "Prompt.lua names no " .. key)
		else
			local name = path:match("Textures\\([%w_]+)$")
			local file = name and (dir .. "/Textures/" .. name .. ".tga")
			if not (file and slurp(file)) then
				fail(scenario, key .. " names " .. tostring(path) .. ", which is not in the package")
			elseif not MC.pow2(file) then
				fail(scenario, name .. ".tga is not a power of two up to 256 a side")
			end
		end
	end
	if not near(lib.BEZEL_FRAME, BEZEL_FRAME, 1e-6) then
		fail(scenario, "Prompt.lua's BEZEL_FRAME is " .. tostring(lib.BEZEL_FRAME) .. ", the generator's " .. BEZEL_FRAME)
	end
	-- The generator's own figures, read from its text.
	local source = slurp(dir .. "/" .. GENERATOR) or ""
	local frame = tonumber(source:match("\nICON_FRAME = ([%d%.]+)"))
	local edge, mid = source:match("\nPANE_MID, PANE_EDGE = ([%d%.]+), ([%d%.]+)")
	if not near(frame, BEZEL_FRAME, 1e-6) then fail(scenario, "the generator's ICON_FRAME is " .. tostring(frame)) end
	if not (near(tonumber(mid), PANE_EDGE, 1e-6) and near(tonumber(edge), PANE_MID, 1e-6)) then
		fail(scenario, "the generator's pane greys are not the ink's " .. tostring(edge) .. "/" .. tostring(mid))
	end
	local text = slurp(dir .. "/Prompt/Text.lua") or ""
	local tMid = text:match("\nlocal PANE_MID = ([%d%.]+)")
	if not near(tonumber(tMid), PANE_MID, 1e-6) then
		fail(scenario, "Text.lua's pane grey is " .. tostring(tMid) .. ", the generator's " .. PANE_MID)
	end
end)

-- ------------------------------------------------------------------ 10
-- The generator draws the same bytes twice, and the bytes that ship.
withTree("panel-material: the generator draws the same bytes twice and what ships", ANNA, function(_, scenario)
	local a, b = tempDir("a"), tempDir("b")
	local outA, outB = generate(a), generate(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generators need numpy and Pillow.
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then
		fail(scenario, ("the generator named %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 300)))
	end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/" .. file)
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif one ~= ships then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
	end
	removeAll(a)
	removeAll(b)
end)

-- ------------------------------------------------------------------ 11
-- The pane and the rim stay under their caps; the vertex-tinted art is grey.
withTree("panel-material: the pane and rim stay under their caps", ANNA, function(_, scenario)
	for _, case in ipairs({ { "GlassPane", 0.80 }, { "TooltipRim", 0.80 } }) do
		local ok, maxLuma = MC.capOK(dir .. "/Textures/" .. case[1] .. ".tga", case[2])
		if not ok then
			fail(scenario, ("%s.tga reaches luma %s, over its cap of %.2f"):format(case[1], tostring(maxLuma), case[2]))
		end
	end
	for _, name in ipairs({ "GlassPane", "IconBezel", "IconBezelRound", "TooltipRim" }) do
		if not MC.isGrey(dir .. "/Textures/" .. name .. ".tga") then
			fail(scenario, name .. ".tga carries a colour of its own, and vertex colour tints it")
		end
	end
	-- The pane is a mid grey the panel colour is drawn through, between its
	-- edge and its middle: neither white glass nor a dark fill.
	local _, mean = MC.underText(dir .. "/Textures/GlassPane.tga")
	if not (mean and mean >= PANE_EDGE - 0.02 and mean <= PANE_MID + 0.02) then
		fail(scenario, ("the pane's mean luma is %s, outside %.2f..%.2f"):format(tostring(mean), PANE_EDGE, PANE_MID))
	end
	for _, name in ipairs(FILES) do
		if not MC.pow2(dir .. "/Textures/" .. name .. ".tga") then
			fail(scenario, name .. ".tga is not a power of two up to 256 a side")
		end
	end
end)

-- GlassLight.tga as the generator draws it now when it can run, else the
-- file that ships; nil (and a SKIPPED line) when neither reads as a 32-bit
-- TGA. Returns the file and the folder to clear.
local function freshLight(scenario, tag)
	local out = tempDir(tag)
	local printed = generate(out)
	local path = out .. "/GlassLight.tga"
	if not (printed and slurp(path)) then path = dir .. "/Textures/GlassLight.tga" end
	local tga = MC.readTGA(path)
	if not tga then
		fail(scenario, "SKIPPED -- GlassLight.tga is not a 32-bit TGA")
		removeAll(out)
		return nil, out
	end
	return tga, out
end

-- The texel (x, row) of the picture as it is seen, row 0 at the top: a TGA
-- keeps its rows bottom-up unless its descriptor says otherwise.
local function seenTexel(tga, x, row)
	local topDown = math.floor(tga.data:byte(18) / 32) % 2 == 1
	return texel(tga, x, topDown and row or (tga.h - 1 - row))
end
local function seenAlpha(tga, x, row)
	local _, _, _, a = seenTexel(tga, x, row)
	return a
end

-- ------------------------------------------------------------------ 12
-- The middle cell of the glass's light (texels 32 to 95 on both axes) is
-- empty: the words lie on it, and the 9-slice stretches it about 7:1 across
-- the panel, so any light drawn there (the caustic it once carried) reads as
-- a smear beside the name.
withTree("panel-material: the middle cell carries no light", ANNA, function(_, scenario)
	local tga, out = freshLight(scenario, "middle")
	if not tga then return end
	local worst, where = 0, ""
	for y = 32, 95 do
		for x = 32, 95 do
			local _, _, _, a = texel(tga, x, y)
			if a > worst then worst, where = a, ("(%d, %d)"):format(x, y) end
		end
	end
	if worst > 0 then
		fail(scenario, ("the glass's light draws in the middle cell, under the words: alpha %.3f at %s"):format(worst, where))
	end
	removeAll(out)
end)

-- ------------------------------------------------------------------ 13
-- The top-left corner, where the cut edge faces the key light, pools the
-- light along the cut and does not show a speck: no brighter than 0.75 (the
-- 0.90 bead read as a stuck pixel), a tenth over the edge's own light for
-- three units along the top and two and a half down the left, tapered back
-- to the edge's own light inside the corner cell (texels 0 to 31), so the
-- stretched strips never carry it, and no spoke of light running in from the
-- corner past the cut's crest (4.5 to 7.5 texels in: the cut is the outer 6,
-- and the refraction line starts at 10). The straight edges keep their own
-- light over the cut (texels 0 to 6): the top at most 0.30, the left at most
-- 0.25, the top no dimmer than the left (it faces the light more squarely).
withTree("panel-material: the light pools along the cut corner", ANNA, function(_, scenario)
	local tga, out = freshLight(scenario, "pool")
	if not tga then return end
	-- The brightest of rows (or columns) lo..hi at column (or row) at.
	local function downTop(x, lo, hi)
		local best = 0
		for row = lo, hi do best = math.max(best, seenAlpha(tga, x, row)) end
		return best
	end
	local function acrossLeft(row, lo, hi)
		local best = 0
		for x = lo, hi do best = math.max(best, seenAlpha(tga, x, row)) end
		return best
	end
	-- The straight edges' own light over the cut, clear of the refraction
	-- line (10 texels in and more).
	local top, left = downTop(64, 0, 6), acrossLeft(64, 0, 6)
	if top > 0.30 or left > 0.25 or top < left then
		fail(scenario, ("the straight edges' light is %.2f along the top and %.2f down the left, not at most 0.30 and 0.25 with the top the brighter"):format(top, left))
	end
	local peak = 0
	for row = 0, 7 do
		for x = 0, 7 do peak = math.max(peak, seenAlpha(tga, x, row)) end
	end
	if peak > 0.75 or peak < 0.55 then
		fail(scenario, ("the corner's light peaks at %.2f, not 0.55 to 0.75"):format(peak))
	end
	for x = 4, 12 do
		local a = downTop(x, 0, 5)
		if a < top + 0.10 then
			fail(scenario, ("the corner's light is gone %d texels along the top: %.2f over the edge's %.2f"):format(x, a, top))
			break
		end
	end
	for row = 4, 10 do
		local a = acrossLeft(row, 0, 5)
		if a < left + 0.10 then
			fail(scenario, ("the corner's light is gone %d texels down the left: %.2f over the edge's %.2f"):format(row, a, left))
			break
		end
	end
	for at = 26, 31 do
		local t, l = downTop(at, 0, 6), acrossLeft(at, 0, 6)
		if math.abs(t - top) > 0.01 or math.abs(l - left) > 0.01 then
			fail(scenario, ("the corner's light runs out of the corner cell: %.2f along the top and %.2f down the left at texel %d"):format(t, l, at))
			break
		end
	end
	-- Past the cut's crest, before the refraction line, nothing brighter than
	-- the top edge's own light.
	for row = 0, 15 do
		for x = 0, 15 do
			local qx, qy = math.abs(x + 0.5 - 64) - 56, math.abs(row + 0.5 - 64) - 56
			local inward = 8 - math.sqrt(math.max(qx, 0) ^ 2 + math.max(qy, 0) ^ 2) - math.min(math.max(qx, qy), 0)
			local a = seenAlpha(tga, x, row)
			if inward >= 4.5 and inward <= 7.5 and a > top + 0.03 then
				fail(scenario, ("a spoke of light runs in from the corner: %.2f at (%d, %d), %.1f texels in"):format(a, x, row, inward))
				removeAll(out)
				return
			end
		end
	end
	removeAll(out)
end)

-- ------------------------------------------------------------------ 14
-- The pane reads as a thick slab of cut glass seen from the front, struck from
-- the upper left, all of it at the edges (the file's 32-texel margins are
-- drawn 8 units square, four texels to the unit). From every edge in, at the
-- middle of its strip: the polished cut (texels 0 to 5); a dark gap a unit
-- wide (nothing in texels 6 to 8, the line's soft edge in 9), so the cut and
-- the line stay two at scale 0.7; then the refraction line, a unit wide and
-- 3 units in (texels 10 to 13 each at half its peak or more, 9 and 14 under
-- half).
-- Along the top and left the line is light: 0.60 to 0.72 at the top's middle
-- (REFRACT_LIT 0.70 at the corner, never a glare), brighter along the top
-- than down the left, which faces the key light less squarely, and brighter
-- at the top's left end than its right, falling away round the slab; its
-- colour the cool white of a glass edge: green the strongest channel, red
-- 0.10 to 0.18 under it and blue 0.02 to 0.08 (greener reads as mint by the
-- gold bezel, white as lacquer's highlight).
-- Along the bottom and right the cut keeps a fill light of 0.22 to 0.26, so
-- the pane stays outlined at small scales and in a landing, no brighter than
-- the top's own cut; and the line is dark there (black texels drawn BLEND, so
-- the pane darkens and the landing's additive copy adds nothing).
-- Under the top line a faint glow, 0.10 to 0.20, gone by texel 24 (6 units
-- in), long before the words.
withTree("panel-material: the slab's edge reads as thick glass", ANNA, function(_, scenario)
	local tga, out = freshLight(scenario, "slab")
	if not tga then return end
	local function most(x0, x1, r0, r1)
		local best, br, bg, bb = 0, 0, 0, 0
		for row = r0, r1 do
			for x = x0, x1 do
				local r, g, b, a = seenTexel(tga, x, row)
				if a > best then best, br, bg, bb = a, r, g, b end
			end
		end
		return best, br, bg, bb
	end
	-- The alpha n texels in from an edge, at the middle of its strip.
	local INWARD = {
		top = function(n) return 64, n end,
		left = function(n) return n, 64 end,
		bottom = function(n) return 64, 127 - n end,
		right = function(n) return 127 - n, 64 end,
	}
	local function inward(side, n)
		local x, row = INWARD[side](n)
		return seenAlpha(tga, x, row)
	end
	for _, side in ipairs({ "top", "left", "bottom", "right" }) do
		local gap = 0
		for n = 6, 8 do gap = math.max(gap, inward(side, n)) end
		if gap > 0.02 then
			fail(scenario, ("along the %s the gap between the cut and the line is not dark 6 to 8 texels in: alpha %.2f"):format(side, gap))
		end
		local peak = 0
		for n = 9, 14 do peak = math.max(peak, inward(side, n)) end
		local whole = peak > 0
		for n = 10, 13 do
			if inward(side, n) < peak / 2 then whole = false end
		end
		if not whole or inward(side, 9) >= peak / 2 or inward(side, 14) >= peak / 2 then
			fail(scenario, ("along the %s the line is not a unit wide 10 to 13 texels in: %.2f %.2f %.2f %.2f %.2f %.2f from texel 9")
				:format(side, inward(side, 9), inward(side, 10), inward(side, 11), inward(side, 12), inward(side, 13), inward(side, 14)))
		end
	end
	local top, tr, tg, tb = most(64, 64, 10, 13)
	local left = most(10, 13, 64, 64)
	local topEnd = most(95, 95, 10, 13)
	if top < 0.60 or top > 0.72 then
		fail(scenario, ("the refraction line is %.2f at the top's middle, not 0.60 to 0.72"):format(top))
	end
	if left < 0.25 or left >= top or topEnd >= top then
		fail(scenario, ("the refraction line is %.2f at the top's middle, %.2f at its right end and %.2f down the left: not lit from the upper left"):format(top, topEnd, left))
	end
	if not (tg >= tr and tg >= tb and tg - tr >= 0.10 and tg - tr <= 0.18 and tg - tb >= 0.02 and tg - tb <= 0.08) then
		fail(scenario, ("the refraction line's colour is (%.2f, %.2f, %.2f), not the cool white of a glass edge"):format(tr, tg, tb))
	end
	local topCut = most(64, 64, 0, 5)
	local bottomCut, rightCut = most(64, 64, 122, 127), most(122, 127, 64, 64)
	if math.min(bottomCut, rightCut) < 0.22 or math.max(bottomCut, rightCut) > 0.26
		or math.max(bottomCut, rightCut) > topCut then
		fail(scenario, ("the cut along the bottom and right is %.2f and %.2f, not a fill light of 0.22 to 0.26 under the top's %.2f")
			:format(bottomCut, rightCut, topCut))
	end
	local bottom, dr, dg, db = most(64, 64, 114, 117)
	local right, rr, rg, rb = most(114, 117, 64, 64)
	if bottom < 0.25 or right < 0.15 or math.max(dr, dg, db, rr, rg, rb) > 0.05 then
		fail(scenario, ("along the bottom and right the line is (%.2f, %.2f, %.2f) at %.2f and (%.2f, %.2f, %.2f) at %.2f, not a darker line")
			:format(dr, dg, db, bottom, rr, rg, rb, right))
	end
	local glow = most(64, 64, 15, 20)
	local tail = most(32, 95, 24, 31)
	if glow < 0.10 or glow > 0.20 then
		fail(scenario, ("the glow under the top line is %.2f, not a faint 0.10 to 0.20"):format(glow))
	end
	if tail > 0 then
		fail(scenario, ("the glow under the top line reaches past 6 units (texel 24), toward the words: alpha %.3f"):format(tail))
	end
	removeAll(out)
end)

-- ------------------------------------------------------------------ 15
-- The slab's light keeps the player's panel. On the default near-black, a
-- light panel, the mid blue and panels made see-through, each of the nine
-- pieces of light is drawn white (so the file's own cool line and black shade
-- come through, never the panel's colour) at exactly 0.9 x the panel's
-- opacity, laid on the pane's own corners, so the refraction line the file
-- draws 12 texels in sits 3 units inside the panel's edge; and the pane's
-- top row ends at exactly the player's colour and opacity.
local PANELS = {
	{ 0.04, 0.04, 0.06, 0.88 },
	{ 0.86, 0.84, 0.78, 0.92 },
	{ 0.30, 0.45, 0.80, 0.92 },
	{ 0.04, 0.04, 0.06, 0.40 },
	{ 0.04, 0.04, 0.06, 0 },
}
withTree("panel-material: the slab's light keeps the player's colour and opacity", ANNA, function(ns, scenario)
	local tga, out = freshLight(scenario, "keeps")
	if not tga then return end
	-- Where the file's line lies down the top's middle: the rows at half its
	-- peak or more, and their middle, in texels.
	local peak, first, last = 0, nil, nil
	for row = 6, 20 do peak = math.max(peak, seenAlpha(tga, 64, row)) end
	for row = 6, 20 do
		if peak > 0 and seenAlpha(tga, 64, row) >= peak / 2 then
			first = first or row
			last = row
		end
	end
	removeAll(out)
	local centre = first and (first + last + 1) / 2 or 0
	for _, c in ipairs(PANELS) do
		local r = upIn(ns, scenario, "glass", function(p) p.bgColor = { c[1], c[2], c[3], c[4] } end)
		local tag = ("(%.2f, %.2f, %.2f, %.2f)"):format(c[1], c[2], c[3], c[4])
		for i, t in ipairs(r.glassLight) do
			local k = t._color
			if not (shown(t) and type(k) == "table" and near(k[1], 1, 1e-6) and near(k[2], 1, 1e-6) and near(k[3], 1, 1e-6)) then
				fail(scenario, ("on %s piece %d of the light is not drawn white: %s"):format(tag, i,
					type(k) == "table" and ("(%.3f, %.3f, %.3f)"):format(k[1] or -1, k[2] or -1, k[3] or -1) or "hidden or unpainted"))
				break
			end
			if not near(k[4], 0.9 * c[4], 1e-6) then
				fail(scenario, ("on %s piece %d of the light is at %.3f, not 0.9 x the panel's opacity"):format(tag, i, k[4] or -1))
				break
			end
		end
		local corner, piece = r.pane[1]._width, r.glassLight[1]
		if not (near(piece._width, corner, 1e-6) and near(piece._height, corner, 1e-6)) then
			fail(scenario, ("on %s the light's corner is %s by %s, the pane's %s"):format(tag, tostring(piece._width),
				tostring(piece._height), tostring(corner)))
		end
		local inset = centre * (piece._width or 0) / 32
		if not near(inset, 3, 0.13) then
			fail(scenario, ("on %s the refraction line lies %.2f units inside the panel's edge, not 3"):format(tag, inset))
		end
		local g = r.pane[2]._gradient
		local hi = g and g[3]
		if not (type(hi) == "table" and near(hi.r, c[1], 1e-6) and near(hi.g, c[2], 1e-6) and near(hi.b, c[3], 1e-6)
			and near(hi.a, c[4], 1e-6)) then
			fail(scenario, ("on %s the pane's top is not the player's colour and opacity: %s"):format(tag,
				type(hi) == "table" and ("(%.3f, %.3f, %.3f, %.3f)"):format(hi.r or -1, hi.g or -1, hi.b or -1, hi.a or -1) or "no gradient"))
		end
	end
end)
