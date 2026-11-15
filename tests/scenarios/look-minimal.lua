-- What Minimal wears (Looks/MinimalDress.lua, a dressing over the Minimal
-- Prompt/Panel.lua draws): a hairline under the words with a tick at each
-- end, the cast bar's spark, the ready check's tick and cross on the icon's
-- corner. Every scenario here is named "look-minimal: ...".
--
-- Run on the recording CreateFrame in tests/frametree.lua. The icon, the
-- bezel, the text and the lights Panel.lua draws on Minimal are held by the
-- scenarios they always had; nothing here asks about them again.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Minimal\\Minimal_"
-- Every file the generator writes, as the Lua names them without Minimal_.
local FILES = { "Line", "Cap", "Glow", "Spark", "Check", "Cross" }
-- What Looks/MinimalDress.lua and the generator agree on, and the figures
-- read here.
local LINE_MID, CAP_W, CAP_H, TICK_X, CORE = 4, 8, 16, 2.4, 0.7
local SPARK_W, SPARK_H, SPARK_HEAD = 32, 16, 0.75
local LINE_UP, LINE_END = 2.5, 8
local CUT_KEEP, FLARE, START_IN = 0.25, 4.5, 3
local REST, OWED, GLOW, TRACK_ALPHA, FILL_LIFT = 0.62, 1, 0.6, 0.5, 0.22
local BREAK = { 1.00, 0.42, 0.20 }
local FLOURISH = 0.6

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
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.01)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Minimal, a passer-by on it (or Anna owed).
local function up(ns, scenario, owed, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.hideInCombat = "minimal", "full", "pulse", false
	-- The hairline is Minimal's earlier art (painted-minimal.lua holds the painting).
	p.classicArt = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	if owed then owe(ns, "Anna Aim") end
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.dress
end

local function skipped(scenario, dress)
	if dress and dress.fillBar and dress.checkSheet then return false end
	fail(scenario, "SKIPPED -- Minimal wears nothing")
	return true
end

local function rectOf(r)
	local x0, x1 = FT.span(r, "x")
	local y0, y1 = FT.span(r, "y")
	if not (x0 and y0) then return nil end
	return { x0, y0, x1, y1 }
end

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end

local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function plays(g) return g and g._plays or 0 end

local function scaleFor(height)
	return math.max(0.55, math.min(1.2, height / 44))
end

local function sameColour(t, r, g, b)
	local v = t._color or {}
	return near(v[1], r) and near(v[2], g) and near(v[3], b)
end

-- ------------------------------------------------------------------ 1
withTree("look-minimal: the art is there, each file a power of two and 32 bits", ANNA, function(ns, scenario)
	for _, name in ipairs(FILES) do
		local h = header(dir .. "/Textures/Minimal/Minimal_" .. name .. ".tga")
		if not h then
			fail(scenario, "Textures/Minimal/Minimal_" .. name .. ".tga is missing")
		else
			for _, side in ipairs({ h.width, h.height }) do
				if side < 1 or side > 256 or math.floor(math.log(side) / math.log(2) + 0.5) ~= math.log(side) / math.log(2) then
					fail(scenario, name .. " is " .. h.width .. "x" .. h.height)
				end
			end
			if h.bits ~= 32 or h.imageType ~= 2 then fail(scenario, name .. " is not a 32-bit uncompressed TGA") end
		end
	end
	-- The hairline's file is as tall as the cap's (the three pieces of a line
	-- are laid at one height, so the client rounds them to the screen alike),
	-- and the cap's is as many texels to the unit both ways.
	local line, cap, spark = header(dir .. "/Textures/Minimal/Minimal_Line.tga"), header(dir .. "/Textures/Minimal/Minimal_Cap.tga"),
		header(dir .. "/Textures/Minimal/Minimal_Spark.tga")
	if line and cap and spark then
		if not (line.height == cap.height and near(cap.width / CAP_W, cap.height / CAP_H)) then
			fail(scenario, ("the hairline's file is %d tall and the cap's %d by %d: not one height, or not the shape the cap is laid at"):format(
				line.height, cap.width, cap.height))
		end
		if not near(spark.width / SPARK_W, spark.height / SPARK_H) then fail(scenario, "the spark's file is not the shape it is laid at") end
	end
	-- And nothing drawn names a file that is not written.
	local _, _, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local known = {}
	for _, name in ipairs(FILES) do known[(ART .. name):lower()] = true end
	for _, t in ipairs(dress.own) do
		if not known[tostring(t._file):lower()] then fail(scenario, "a texture draws " .. tostring(t._file)) end
	end
	local toc = io.open(dir .. "/Manners.toc", "rb"):read("*a")
	local flow, looks, mine = toc:find("Looks\\Flow.lua", 1, true), toc:find("Looks\\Looks.lua", 1, true), toc:find("Looks\\MinimalDress.lua", 1, true)
	local prompt = toc:find("Prompt\\Prompt.lua", 1, true)
	if not (flow and looks and mine and prompt and looks < flow and flow < mine and mine < prompt) then
		fail(scenario, "the toc does not load Looks.lua, Flow.lua and MinimalDress.lua in that order, before the prompt")
	end
	-- Minimal keeps its key, its name and its place in the picker.
	local title, line2 = ns.Looks.Card("minimal")
	if title ~= ns.L["Minimal"] or line2 ~= ns.L["a thin rim, a soft pane, one fine line"] or ns.Looks.list.minimal.order ~= 12 then
		fail(scenario, "Minimal's card is no longer Minimal's")
	end
	if ns.Looks.Get("minimal") ~= nil then fail(scenario, "Minimal is a look of its own now, not Panel.lua's with a dressing") end
end)

-- ------------------------------------------------------------------ 2
withTree("look-minimal: a hairline under the words, from where they start, a tick at each end", ANNA, function(ns, scenario)
	for _, size in ipairs({ { 220, 44, true }, { 320, 58, true }, { 160, 26, true }, { 420, 100, true }, { 220, 44, false }, { 80, 36, true } }) do
		local r, p, dress = up(ns, scenario, false, function(p)
			p.width, p.height, p.showIcon = size[1], size[2], size[3]
		end)
		if skipped(scenario, dress) then return end
		local W, Ht = size[1], size[2]
		local tag = W .. "x" .. Ht .. (size[3] and "" or ", no icon")
		local k = scaleFor(Ht)
		local art, box = rectOf(r.art), rectOf(dress.box)
		local nameLeft = FT.span(r.name, "x")
		if not (box and FT.visible(dress.track[2])) then
			fail(scenario, tag .. ": the line is not drawn")
		else
			-- The left tick's outer edge flush with the words, the right one's
			-- LINE_END short of the panel's edge.
			local out = (TICK_X - CORE) * k
			if not near(box[1] + out, nameLeft, 0.05) then
				fail(scenario, ("%s: the left tick stands at %.1f, the words start at %.1f"):format(tag, box[1] + out, nameLeft))
			end
			if not near(box[3] - out, art[3] - LINE_END, 0.05) then
				fail(scenario, ("%s: the right tick stands %.1f short of the panel's edge, not %d"):format(tag, art[3] - (box[3] - out), LINE_END))
			end
			-- Its light where Panel.lua's bottom rule lies, scaled with the panel.
			local middle = box[2] + LINE_MID * k - art[2]
			if not near(middle, LINE_UP * k, 0.05) then
				fail(scenario, ("%s: the line's light is %.2f over the panel's foot, not %.2f"):format(tag, middle, LINE_UP * k))
			end
			-- Under the reason line, never in it.
			if r.sub and FT.visible(r.sub) then
				local subFoot = select(1, FT.span(r.sub, "y"))
				if box[2] + (LINE_MID + CORE) * k > subFoot then fail(scenario, tag .. ": the hairline is drawn in the reason line") end
			end
		end
		-- Three lines of the same three pieces: unlit, lit, and the flash.
		for which, b in pairs({ track = dress.track, fill = dress.fillBar, hot = dress.hotBar }) do
			local capL, mid, capR = rectOf(b[1]), rectOf(b[2]), rectOf(b[3])
			if not (capL and mid and capR) then
				fail(scenario, tag .. ": the " .. which .. " line has a piece missing")
			else
				if not (near(capL[3] - capL[1], CAP_W * k) and near(capL[4] - capL[2], CAP_H * k) and near(capR[3] - capR[1], CAP_W * k)) then
					fail(scenario, ("%s: the %s line's cap is %.1f by %.1f, not %.1f by %.1f"):format(tag, which,
						capL[3] - capL[1], capL[4] - capL[2], CAP_W * k, CAP_H * k))
				end
				if not (near(mid[1], capL[3]) and near(mid[3], capR[1]) and near(mid[2], capL[2])) then
					fail(scenario, tag .. ": the " .. which .. " line's hairline does not join its caps")
				end
				-- One height for all three: pieces of two heights are rounded to
				-- the screen apart, a step in the hairline where they meet.
				if not (near(mid[4] - mid[2], capL[4] - capL[2]) and near(capR[4] - capR[2], capL[4] - capL[2])) then
					fail(scenario, ("%s: the %s line's hairline is %.1f tall beside caps of %.1f: not one height"):format(tag, which,
						mid[4] - mid[2], capL[4] - capL[2]))
				end
				if not (near(capL[1], box[1]) and near(capR[3], box[3]) and near(capL[2], box[2])) then
					fail(scenario, tag .. ": the " .. which .. " line is not laid in the line's box")
				end
				local l, rr = b[1]._texCoord or { 0, 1, 0, 1 }, b[3]._texCoord or {}
				if not (l[1] < l[2] and (rr[1] or 0) > (rr[2] or 0)) then fail(scenario, tag .. ": the " .. which .. " line's right tick is not the left one turned round") end
				if not (tostring(b[1]._file):find("Minimal_Cap", 1, true) and tostring(b[2]._file):find("Minimal_Line", 1, true)) then
					fail(scenario, tag .. ": the " .. which .. " line is drawn from the wrong files")
				end
			end
		end
		-- At rest: the unlit line faint and grey, the lit one in the reason's
		-- colour over it, neither additive; the flashes at nothing.
		for i = 1, 3 do
			if dress.track[i]._blend == "ADD" or dress.fillBar[i]._blend == "ADD" then fail(scenario, tag .. ": the line is additive at rest") end
			if dress.hotBar[i]._blend ~= "ADD" then fail(scenario, tag .. ": the line's flash is not additive") end
			if not near(dress.track[i]:GetAlpha(), TRACK_ALPHA, 0.001) then fail(scenario, tag .. ": the unlit line is at " .. tostring(dress.track[i]:GetAlpha())) end
		end
		if not near(dress.fill:GetAlpha(), REST, 0.001) then fail(scenario, tag .. ": the lit line rests at " .. tostring(dress.fill:GetAlpha())) end
		if (dress.hot:GetAlpha() or 1) > 0.001 or (dress.ping:GetAlpha() or 1) > 0.001 or (dress.badge:GetAlpha() or 1) > 0.001 then
			fail(scenario, tag .. ": a flash or the mark is up at rest")
		end
		if (dress.glow:GetAlpha() or 1) > 0.001 then fail(scenario, tag .. ": the line glows with nobody owed") end
		-- The cut holds the fill and the three sparks. It is the spark's height,
		-- and the hairline's middle is its own.
		local clip = rectOf(dress.clip)
		if not (dress.clip._ft and dress.clip._ft.clips) then fail(scenario, tag .. ": the fill is not cut at the line's ends") end
		if not (clip and box and near(clip[4] - clip[2], SPARK_H * k) and near((clip[2] + clip[4]) / 2, box[2] + LINE_MID * k, 0.05)) then
			fail(scenario, tag .. ": the cut is not the line's length and the spark's height")
		elseif nameLeft then
			-- On the left it stands at the tick's outer edge, a quarter unit
			-- kept for the edge's own softness: the fill is cast from that side
			-- and a spark's tail trails that way, and neither may be seen left
			-- of where the line starts.
			if not near(clip[1], nameLeft - CUT_KEEP * k, 0.05) then
				fail(scenario, ("%s: the cut starts %.2f left of the left tick: a line being cast is seen outside its tick"):format(tag, nameLeft - clip[1]))
			end
			-- On the right it leaves a spark's flare room past the far tick,
			-- and that room is inside the panel.
			if not near(clip[3], box[3] + FLARE * k, 0.05) then
				fail(scenario, ("%s: the cut ends %.2f past the line's box: a spark's flare is sheared at the far tick"):format(tag, clip[3] - box[3]))
			end
			if clip[3] > art[3] + 0.01 then fail(scenario, ("%s: the cut reaches %.2f outside the panel"):format(tag, clip[3] - art[3])) end
		end
		-- The cast's spark rests with its head on the left tick; the two that
		-- fade in standing still, START_IN inside it. Each rides the hairline.
		for _, f in ipairs({ dress.spark, dress.rover, dress.glint }) do
			local s = rectOf(f)
			if not s then
				fail(scenario, tag .. ": a spark is not placed")
			else
				local head = s[1] + SPARK_HEAD * (s[3] - s[1])
				local want = box[1] + (TICK_X + (f == dress.spark and 0 or START_IN)) * k
				if not near(head, want, 0.05) then fail(scenario, ("%s: a spark's head rests at %.1f, not at %.1f"):format(tag, head, want)) end
				if not near((s[2] + s[4]) / 2, box[2] + LINE_MID * k, 0.05) then fail(scenario, tag .. ": a spark does not ride the hairline") end
			end
			if f.tex._blend == "ADD" then fail(scenario, tag .. ": a spark that loops is additive") end
		end
	end
end)

-- ------------------------------------------------------------------ 3
withTree("look-minimal: nothing grows: no animation of Minimal's is a scale, and its light stays under the text", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	if #dress.anims < 10 then fail(scenario, "only " .. #dress.anims .. " of the animations are listed") end
	for _, g in ipairs(dress.anims) do
		for _, a in ipairs(g._anims) do
			if a._kind ~= "Alpha" and a._kind ~= "Translation" then fail(scenario, "an animation of Minimal's is a " .. tostring(a._kind)) end
		end
	end
	local text = r.textLayer:GetFrameLevel()
	for _, f in ipairs({ dress.frame, dress.box, dress.clip, dress.fill, dress.spark, dress.rover, dress.glint, dress.hot, dress.ping, dress.badge }) do
		if f:GetFrameLevel() >= text then fail(scenario, "a frame of Minimal's light is level with the text or over it") end
	end
	-- Nothing of it hangs off the secure button.
	local button = ns.Prompt:GetButton()
	for _, t in ipairs(dress.own) do
		if t:GetParent() == button then fail(scenario, "a texture of Minimal's is the button's own") end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("look-minimal: switched off it is Minimal as it was, and another look takes it all off", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario, true)
	if skipped(scenario, dress) then return end
	local function gone(when)
		for _, t in ipairs(dress.own) do
			if FT.visible(t) then fail(scenario, when .. " a piece of Minimal's is still drawn: " .. tostring(t._file)) break end
		end
		if dress.flow.driver:IsShown() then fail(scenario, when .. " Minimal's clock still runs") end
		for _, g in ipairs(dress.anims) do
			if g._playing then fail(scenario, when .. " an animation of Minimal's still plays") break end
		end
	end
	if not FT.visible(dress.track[2]) then fail(scenario, "as it comes, Minimal has no line") end
	p.minimalLine = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	gone("with the line switched off")
	-- And stays off through what the prompt asks of it.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "y")
	tick(ns)
	gone("switched off, after an outcome,")
	p.minimalLine = nil
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not FT.visible(dress.track[2]) then fail(scenario, "switched back on, the line did not come") end
	-- Another look of Panel.lua's, then one from Looks/: nothing of Minimal's left.
	for _, style in ipairs({ "framed", "glass", "forge" }) do
		p.style = style
		ns.Prompt:ApplyStyle()
		tick(ns)
		if ns.Prompt:Regions().dress == dress then fail(scenario, style .. " still wears Minimal's dressing") end
		gone("on " .. style)
	end
	p.style = "minimal"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (ns.Prompt:Regions().dress == dress and FT.visible(dress.track[2])) then fail(scenario, "back on Minimal, the line did not come back") end
end)

-- ------------------------------------------------------------------ 5
withTree("look-minimal: at rest a glint crosses the line on Full; not on Calm, in a fight or with the prompt down", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local function loops()
		local n = 0
		for _, g in ipairs(dress.anims) do
			if g._playing and g._looping and g._looping ~= "NONE" then n = n + 1 end
		end
		return n
	end
	if not dress.drift._playing then fail(scenario, "at rest on Full the glint does not run") end
	if loops() ~= 1 then fail(scenario, "at rest " .. loops() .. " loops run, not the glint alone") end
	if not (#dress.idle == 1 and dress.idle[1] == dress.drift) then fail(scenario, "what loops at rest is not named") end
	if dress.drift._looping ~= "REPEAT" then fail(scenario, "the glint does not come round again") end
	-- It runs from where it starts, START_IN inside the left tick, to the far
	-- tick, and is gone before it gets there.
	local box = rectOf(dress.box)
	local k = scaleFor(p.height)
	local run = (box[3] - box[1]) - (2 * TICK_X + START_IN) * k
	local off = dress.drift.run._offset or {}
	if not (near(off[1], run, 0.05) and near(off[2], 0)) then fail(scenario, ("the glint runs %s units along a line of %.1f"):format(tostring(off[1]), run)) end
	-- A wider panel, a longer run.
	p.width = 320
	ns.Prompt:ApplyStyle()
	tick(ns)
	box = rectOf(dress.box)
	off = dress.drift.run._offset or {}
	if not near(off[1], (box[3] - box[1]) - (2 * TICK_X + START_IN) * k, 0.05) then fail(scenario, "on a wider panel the glint still runs the old line's length") end
	-- A turn takes seconds: a prompt at rest is not busy.
	if FT.groupLength(dress.drift) < 4 then fail(scenario, ("the glint comes round every %.1f s"):format(FT.groupLength(dress.drift))) end

	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if loops() ~= 0 then fail(scenario, "on Calm " .. loops() .. " of Minimal's loops run") end
	if not FT.visible(dress.fillBar[2]) then fail(scenario, "on Calm the line is gone") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not dress.drift._playing then fail(scenario, "back on Full the glint does not run") end

	fight(ns, true)
	tick(ns)
	if loops() ~= 0 then fail(scenario, "in a fight " .. loops() .. " of Minimal's loops run") end
	fight(ns, false)
	tick(ns)
	if not dress.drift._playing then fail(scenario, "after the fight the glint does not come back") end

	-- Nobody left: the prompt comes down and nothing of Minimal's goes on.
	strangers({})
	ns.BlockPerson("Anna Aim")
	for _ = 1, 4 do
		Mock.advance(3)
		tick(ns)
	end
	if ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come down with nobody left")
	elseif loops() ~= 0 then
		fail(scenario, "with the prompt down " .. loops() .. " of Minimal's loops run")
	end
end)

-- ------------------------------------------------------------------ 6
withTree("look-minimal: somebody owed casts the line, then it breathes and the spark runs it", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local casts, sparks = plays(dress.fillIn), plays(dress.cast)
	if casts ~= 0 then fail(scenario, "a passer-by on the prompt cast the line") end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(dress.fillIn) ~= casts + 1 or plays(dress.cast) ~= sparks + 1 then fail(scenario, "somebody buffing you did not cast the line") end
	-- The fill starts a line's length to the left and comes home; the spark
	-- starts on its leading end and goes the same distance in the same time.
	local box = rectOf(dress.box)
	local wide, k = box[3] - box[1], scaleFor(p.height)
	local away, home = dress.fillIn.away._offset or {}, dress.fillIn.home._offset or {}
	if not (near(away[1], -wide, 0.05) and near(home[1], wide, 0.05)) then fail(scenario, "the fill does not slide in from a line's length away") end
	-- It leaves while it is hidden: the first step holds it at nothing for
	-- longer than the way out takes.
	local hidden = dress.fillIn._anims[1]
	if not (hidden._kind == "Alpha" and hidden._fromAlpha == 0 and hidden._toAlpha == 0 and hidden._order == 1
		and dress.fillIn.away._order == 1 and (dress.fillIn.away._duration or 1) <= hidden._duration) then
		fail(scenario, "the fill is seen leaving before it is cast")
	end
	local back, runBy = dress.cast.away._offset or {}, dress.cast.run._offset or {}
	if not (near(back[1], -2 * TICK_X * k, 0.05) and near(runBy[1], wide, 0.05)) then fail(scenario, "the spark does not ride the fill's leading end") end
	if not near(dress.cast.run._duration, dress.fillIn.home._duration, 0.001) or dress.cast.run._smoothing ~= dress.fillIn.home._smoothing then
		fail(scenario, "the spark and the fill do not move as one")
	end
	if dress.drift._playing then fail(scenario, "the glint at rest runs with somebody owed") end
	-- The same favour at the next scans: not cast again.
	Mock.advance(0.2)
	ns.addon:Tick()
	if plays(dress.fillIn) ~= casts + 1 then fail(scenario, "the line was cast again on a repaint of the same favour") end
	-- The cast over: the far tick caught the spark, the line stands at full
	-- and glows in the owed colour, breathing, the spark running it.
	local pinged = plays(dress.pinged)
	Mock.advance(0.6)
	FT.settle()
	if plays(dress.pinged) ~= pinged + 1 then fail(scenario, "the far tick did not catch the spark as the cast ended") end
	if FT.groupLength(dress.pinged) > FLOURISH + 0.001 or dress.pingCap._blend ~= "ADD" then fail(scenario, "the far tick's flash is not a short additive one") end
	local ping, capR = rectOf(dress.ping), rectOf(dress.track[3])
	if not (ping and near(ping[1], capR[1]) and near(ping[3], capR[3]) and near(ping[2], capR[2])) then fail(scenario, "the flash is not on the far tick") end
	if not near(dress.fill:GetAlpha(), OWED, 0.001) then fail(scenario, "the cast over, the lit line is at " .. tostring(dress.fill:GetAlpha())) end
	if not (dress.breath._playing and dress.patrol._playing) then fail(scenario, "the owed line does not breathe, or the spark does not run it") end
	if dress.breath._looping ~= "BOUNCE" or dress.patrol._looping ~= "REPEAT" then fail(scenario, "the owed loops do not loop") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local Tint = ns.Prompt.lib.Tint
	local fr, fg, fb = Tint(cr, cg, cb, FILL_LIFT)
	for i = 1, 3 do
		if not sameColour(dress.fillBar[i], fr, fg, fb) then fail(scenario, "piece " .. i .. " of the lit line is not in the owed colour") end
	end
	if not (sameColour(dress.glow, cr, cg, cb) and near(dress.glow:GetAlpha(), GLOW, 0.001)) then fail(scenario, "the owed line does not glow in the owed colour") end
	if dress.glow._blend == "ADD" then fail(scenario, "the glow that rests is additive") end
	local off = dress.patrol.run._offset or {}
	if not near(off[1], wide - (2 * TICK_X + START_IN) * k, 0.05) then fail(scenario, "the spark does not run from tick to tick") end
	-- The marker off: plain warm light, not the reason's colour.
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if sameColour(dress.fillBar[2], fr, fg, fb) then fail(scenario, "with the marker off the line still wears the reason's colour") end
	p.accentMode = "icon"

	-- Calm: the line stands, lit and still.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if dress.breath._playing or dress.patrol._playing or dress.fillIn._playing or dress.cast._playing then fail(scenario, "on Calm something of Minimal's moves with somebody owed") end
	if not (near(dress.fill:GetAlpha(), OWED, 0.001) and near(dress.glow:GetAlpha(), GLOW, 0.001)) then fail(scenario, "on Calm the owed line is not lit") end
	-- Flash once: cast, and then still.
	p.effects, p.flashStyle = "full", "once"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if dress.breath._playing or dress.patrol._playing then fail(scenario, "on Flash once the owed loops run") end
	-- Flash off: an owed line is a line at rest.
	p.flashStyle = "off"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not near(dress.fill:GetAlpha(), REST, 0.001) or (dress.glow:GetAlpha() or 1) > 0.001 then fail(scenario, "with Flash off the owed line is lit as if it flashed") end
	p.flashStyle = "pulse"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not dress.breath._playing then fail(scenario, "back on Pulse the owed line does not breathe") end

	-- The favour done: the loops stop, the line rests, the glint comes back.
	wipe(ns.owed)
	tick(ns)
	tick(ns)
	if dress.breath._playing or dress.patrol._playing then fail(scenario, "nobody owed any more, and the owed loops run on") end
	if not near(dress.fill:GetAlpha(), REST, 0.001) then fail(scenario, "nobody owed, and the line stays at " .. tostring(dress.fill:GetAlpha())) end
	if (dress.glow:GetAlpha() or 1) > 0.001 then fail(scenario, "nobody owed, and the line still glows") end
	if not near(dress.clip:GetAlpha(), 1, 0.001) then fail(scenario, "the breath left the line dimmed") end
	if not dress.drift._playing then fail(scenario, "nobody owed, and the glint at rest does not come back") end
end)

-- ------------------------------------------------------------------ 7
withTree("look-minimal: a landing dashes the line, flashes it and strikes the tick on the icon", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	-- The line still being cast when the buff lands: the landing finishes it.
	local dash, flash, stamp = plays(dress.dash), plays(dress.flash), plays(dress.stamp)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if dress.fillIn._playing or dress.cast._playing then fail(scenario, "a landing left the line half cast") end
	if not near(dress.fill:GetAlpha(), OWED, 0.001) then fail(scenario, "a landing left the lit line at " .. tostring(dress.fill:GetAlpha())) end
	if plays(dress.dash) ~= dash + 1 or plays(dress.flash) ~= flash + 1 then fail(scenario, "a landing did not dash the line and flash it") end
	if plays(dress.stamp) ~= stamp + 1 then fail(scenario, "a landing did not strike the mark") end
	if not (dress.check:IsShown() and not dress.cross:IsShown()) then fail(scenario, "a landing's mark is not the tick") end
	if not dress.checkSheet:IsPlaying() or dress.crossSheet:IsPlaying() then fail(scenario, "the tick is not being struck") end
	if not dress.flow.driver:IsShown() then fail(scenario, "nothing plays the tick's frames") end
	for _, g in ipairs({ dress.flash, dress.dash }) do
		if FT.groupLength(g) > FLOURISH + 0.001 then fail(scenario, ("a landing's light lasts %.2f s"):format(FT.groupLength(g))) end
	end
	-- The dash goes from the one tick to the other.
	local lineBox = rectOf(dress.box)
	local dashed = dress.dash.run._offset or {}
	if not near(dashed[1], (lineBox[3] - lineBox[1]) - 2 * TICK_X * scaleFor(p.height), 0.05) then
		fail(scenario, ("a landing's spark dashes %s units, not from tick to tick"):format(tostring(dashed[1])))
	end
	-- The mark: on the icon's lower right corner, eight frames in a sheet four
	-- across, its last frame the one it rests on.
	local badge, icon = rectOf(dress.badge), rectOf(r.icon)
	local cx, cy = (badge[1] + badge[3]) / 2, (badge[2] + badge[4]) / 2
	if not (cx > (icon[1] + icon[3]) / 2 and cx < icon[3] and cy < (icon[2] + icon[4]) / 2 and cy > icon[2]) then
		fail(scenario, "the mark is not on the icon's lower right corner")
	end
	if not near(badge[3] - badge[1], math.max(12, p.iconSize * 0.72), 0.05) then fail(scenario, ("the mark is %.1f across an icon of %d"):format(badge[3] - badge[1], p.iconSize)) end
	local sheet = dress.checkSheet
	if not (sheet.cols == 4 and sheet.rows == 2 and sheet.frames == 8 and not sheet.loop) then fail(scenario, "the tick's sheet is not eight frames, four across, played once") end
	local c = dress.check._texCoord or {}
	if not (near(c[1], 0) and near(c[2], 0.25) and near(c[3], 0) and near(c[4], 0.5)) then fail(scenario, "the tick does not start on its first frame") end
	Mock.advance(0.3)
	dress.flow:Tick(GetTime())
	c = dress.check._texCoord or {}
	if not (near(c[1], 0.75) and near(c[2], 1) and near(c[3], 0.5) and near(c[4], 1)) then fail(scenario, "the tick does not rest on its last frame") end
	if dress.checkSheet:IsPlaying() or dress.flow.driver:IsShown() then fail(scenario, "the tick struck, the clock runs on") end
	if dress.check._blend == "ADD" then fail(scenario, "the mark, which stays to be read, is additive") end
	-- Everything goes back to nothing.
	Mock.advance(1)
	FT.settle()
	if (dress.hot:GetAlpha() or 1) > 0.001 or (dress.badge:GetAlpha() or 1) > 0.001 or (dress.spark:GetAlpha() or 1) > 0.001 then
		fail(scenario, "a landing's light or its mark is left on")
	end
	-- A cast nobody confirmed claims nothing.
	dash, stamp = plays(dress.dash), plays(dress.stamp)
	ns.Prompt:ShowOutcome("sent", "Anna Aim", "z")
	if plays(dress.dash) ~= dash or plays(dress.stamp) ~= stamp then fail(scenario, "a cast nobody confirmed got the landing's gesture") end
	-- No icon, no mark: the line answers alone.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	dash, stamp = plays(dress.dash), plays(dress.stamp)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "w")
	if plays(dress.stamp) ~= stamp or FT.visible(dress.check) then fail(scenario, "with the icon off the mark is struck onto nothing") end
	if plays(dress.dash) ~= dash + 1 then fail(scenario, "with the icon off a landing does not dash the line") end
	p.showIcon = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	-- Nor in a fight that holds the panel.
	fight(ns, true)
	tick(ns)
	dash, stamp = plays(dress.dash), plays(dress.stamp)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "v")
	if plays(dress.dash) ~= dash or plays(dress.stamp) ~= stamp then fail(scenario, "in a fight a landing still plays Minimal's gesture") end
end)

-- ------------------------------------------------------------------ 8
withTree("look-minimal: a refusal turns the line red, runs it back out and strikes the cross, and the colour comes back", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario, true)
	if skipped(scenario, dress) then return end
	Mock.advance(1)
	FT.settle()
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local fr, fg, fb = ns.Prompt.lib.Tint(cr, cg, cb, FILL_LIFT)
	local sputter, stamp, dash = plays(dress.sputter), plays(dress.stamp), plays(dress.dash)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(dress.sputter) ~= sputter + 1 then fail(scenario, "a refusal did not sputter the line") end
	if plays(dress.dash) ~= dash then fail(scenario, "a refusal dashed the line as a landing does") end
	for i = 1, 3 do
		if not sameColour(dress.fillBar[i], BREAK[1], BREAK[2], BREAK[3]) then fail(scenario, "piece " .. i .. " of a refused line is not red") end
	end
	if plays(dress.stamp) ~= stamp + 1 or not (dress.cross:IsShown() and not dress.check:IsShown()) then fail(scenario, "a refusal did not strike the cross") end
	if not dress.crossSheet:IsPlaying() or dress.checkSheet:IsPlaying() then fail(scenario, "the cross is not being struck") end
	-- The cast undone: its last step runs the fill a line's length to the left.
	local box = rectOf(dress.box)
	local out = dress.sputter.out._offset or {}
	if not near(out[1], -(box[3] - box[1]), 0.05) then fail(scenario, "the refused line does not run back out the way it was cast") end
	if FT.groupLength(dress.sputter) > 0.5 then fail(scenario, ("the sputter lasts %.2f s"):format(FT.groupLength(dress.sputter))) end
	-- A new reason's colour in the middle of it does not take the red off.
	dress:PaintReason(cr, cg, cb, "owed", "icon")
	if not sameColour(dress.fillBar[2], BREAK[1], BREAK[2], BREAK[3]) then fail(scenario, "a repaint took the red off a line still sputtering") end
	-- Over: the reason's colour again, faded back up to where the line stands.
	local back = plays(dress.back)
	Mock.advance(0.4)
	FT.settle()
	for i = 1, 3 do
		if not sameColour(dress.fillBar[i], fr, fg, fb) then fail(scenario, "the sputter over, piece " .. i .. " of the line is still red") end
	end
	if not sameColour(dress.glow, cr, cg, cb) then fail(scenario, "the sputter over, the glow is still red") end
	if plays(dress.back) ~= back + 1 then fail(scenario, "the line did not fade back in after the sputter") end
	Mock.advance(0.4)
	FT.settle()
	local want = dress.owed and OWED or REST
	if not near(dress.fill:GetAlpha(), want, 0.001) then fail(scenario, ("the line came back at %s, not %s"):format(tostring(dress.fill:GetAlpha()), tostring(want))) end
	-- Cut short by a repaint about somebody else: the red goes at once.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Line of sight.")
	if not sameColour(dress.fillBar[2], BREAK[1], BREAK[2], BREAK[3]) then fail(scenario, "a second refusal did not turn the line red") end
	ns.Prompt:StopFlourishes()
	if not sameColour(dress.fillBar[2], fr, fg, fb) then fail(scenario, "a refusal cut short left the line red") end
	if dress.sputter._playing or dress.stamp._playing or dress.crossSheet:IsPlaying() then fail(scenario, "a refusal's effects play on after a repaint stopped them") end
	if (dress.badge:GetAlpha() or 1) > 0.001 then fail(scenario, "the cross is left on the icon") end
	-- The marks are the ready check's own colours, not the reason's.
	local tk, cx = dress.check._color or {}, dress.cross._color or {}
	if not (tk[2] > tk[1] and tk[2] > tk[3]) then fail(scenario, "the tick is not green") end
	if not (cx[1] > cx[2] and cx[1] > cx[3]) then fail(scenario, "the cross is not red") end
end)

-- ------------------------------------------------------------------ 9
-- The game keeps one alpha for a texture: SetVertexColor's fourth number
-- writes over what SetAlpha set (Looks.lua, ONE ALPHA). Each texture is made
-- to behave as the game's does here, and a reason's colour, an owed favour
-- and a refusal must leave every alpha where the look put it.
withTree("look-minimal: a colour never moves a texture's alpha", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	for _, t in ipairs(dress.own) do
		local set = t.SetVertexColor
		t.SetVertexColor = function(self, cr, cg, cb, ca, ...)
			-- The game's one number, written straight: not through SetAlpha,
			-- which is the look's own and would be taken for its wish.
			self._alpha = ca == nil and 1 or ca
			return set(self, cr, cg, cb, ca, ...)
		end
	end
	local function check(when, glow)
		for i, t in ipairs(dress.own) do
			local want = 1
			if t == dress.glow then want = glow end
			for _, piece in ipairs(dress.track) do
				if t == piece then want = TRACK_ALPHA end
			end
			if not near(t:GetAlpha(), want, 0.001) then
				fail(scenario, ("%s, texture %d (%s) stands at alpha %s, not %s"):format(when, i, tostring(t._file):match("[^\\]+$"),
					tostring(t:GetAlpha()), tostring(want)))
			end
		end
	end
	dress:PaintReason(0.2, 0.8, 0.3, "nearby", "icon")
	check("after a reason's colour", 0)
	dress:PaintReason(0.2, 0.8, 0.3, "nearby", "off")
	check("with the marker off", 0)
	owe(ns, "Anna Aim")
	tick(ns)
	check("with somebody owed", GLOW)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "x")
	check("on a refusal", GLOW)
	Mock.advance(1)
	FT.settle()
	check("after a refusal", GLOW)
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "y")
	Mock.advance(1)
	FT.settle()
	check("after a landing", GLOW)
	wipe(ns.owed)
	tick(ns)
	tick(ns)
	check("with nobody owed again", 0)
end)
