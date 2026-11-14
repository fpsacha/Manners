# Mutations for what Minimal wears (Looks/MinimalDress.lua) and for the hooks
# Prompt/ calls it through. Caught by tests/scenarios/look-minimal.lua.

S = "runscenarios.py"
MIN = "Looks/MinimalDress.lua"

# --- the line and its ticks ---

mutate(MIN,
       "\tlocal x0, x1 = left, W - LINE_END\n",
       "\tlocal x0, x1 = left + 6, W - LINE_END\n",
       "look-minimal: the line starts six units into the words",
       expect="the left tick stands at", script=S)

mutate(MIN,
       "\tlocal x0, x1 = left, W - LINE_END\n",
       "\tlocal x0, x1 = left, W\n",
       "look-minimal: the line runs to the panel's very edge",
       expect="short of the panel's edge", script=S)

mutate(MIN,
       "\tbox:SetPoint(\"BOTTOMLEFT\", art, \"BOTTOMLEFT\", x0 - out, (LINE_UP - LINE_MID) * k)\n",
       "\tbox:SetPoint(\"BOTTOMLEFT\", art, \"BOTTOMLEFT\", x0 - out, 0)\n",
       "look-minimal: the line's light off Panel.lua's bottom rule",
       expect="the line's light is", script=S)

mutate(MIN,
       "\tlocal k = math.max(SCALE_LO, math.min(SCALE_HI, H / SCALE_AT))\n",
       "\tlocal k = 1\n",
       "look-minimal: the line one size on every panel",
       expect="look-minimal: a hairline under the words", script=S)

mutate(MIN,
       "local LINE_MID, CAP_W, CAP_H, TICK_X, CORE = 4, 8, 16, 2.4, 0.7",
       "local LINE_MID, CAP_W, CAP_H, TICK_X, CORE = 4, 8, 8, 2.4, 0.7",
       "look-minimal: the cap's file squashed to half its height",
       expect="line's cap is", script=S)

mutate(MIN,
       "\t\tb[3]:SetTexCoord(1, 0, 0, 1)\n\t\treturn b\n",
       "\t\treturn b\n",
       "look-minimal: the right tick drawn as the left one, turned inward",
       expect="right tick is not the left one turned round", script=S)

mutate(MIN,
       "\tb[2]:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", cap, 0)\n",
       "\tb[2]:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", 0, 0)\n",
       "look-minimal: the hairline drawn through its left cap",
       expect="hairline does not join its caps", script=S)

mutate(MIN,
       "\tfor _, t in ipairs(self.track) do Colour(t, TRACK[1], TRACK[2], TRACK[3], TRACK_ALPHA) end\n",
       "\tfor _, t in ipairs(self.track) do Colour(t, TRACK[1], TRACK[2], TRACK[3], 1) end\n",
       "look-minimal: the unlit line at full strength",
       expect="the unlit line is at", script=S)

mutate(MIN,
       "\tself.hotBar = bar(hot, \"ADD\")\n",
       "\tself.hotBar = bar(hot)\n",
       "look-minimal: the line's flash drawn as paint, not light",
       expect="the line's flash is not additive", script=S)

mutate(MIN,
       "\t\tself.fill:SetAlpha(self.owed and OWED or REST)\n",
       "\t\tself.fill:SetAlpha(OWED)\n",
       "look-minimal: the line at full with nobody owed",
       expect="the lit line rests at", script=S)

mutate(MIN,
       "\tif clip.SetClipsChildren then clip:SetClipsChildren(true) end\n",
       "",
       "look-minimal: the fill seen sliding in from outside the line",
       expect="the fill is not cut at the line's ends", script=S)

mutate(MIN,
       "\tclip:SetSize(wide - cut + FLARE * k, SPARK_H * k)\n",
       "\tclip:SetSize(wide - cut + FLARE * k, 2 * LINE_MID * k)\n",
       "look-minimal: the spark's lens cut off at the line's height",
       expect="the cut is not the line's length and the spark's height", script=S)

# The cut as wide as the caps' files, as it was first built: the fill being
# cast, a refused line running back out and a spark's tail were all seen for
# 1.7 units left of the left tick, where the line has not started.
mutate(MIN,
       "\tlocal cut, under = out - CUT_KEEP * k, (SPARK_H / 2 - LINE_MID) * k\n",
       "\tlocal cut, under = 0, (SPARK_H / 2 - LINE_MID) * k\n",
       "look-minimal: the cut starts at the cap's edge, a cast line seen left of its tick",
       expect="a line being cast is seen outside its tick", script=S)

mutate(MIN,
       "\tclip:SetSize(wide - cut + FLARE * k, SPARK_H * k)\n",
       "\tclip:SetSize(wide - cut, SPARK_H * k)\n",
       "look-minimal: the cut ends at the far cap, the spark's flare sheared there",
       expect="a spark's flare is sheared at the far tick", script=S)

mutate(MIN,
       "local CUT_KEEP, FLARE = 0.25, 4.5\n",
       "local CUT_KEEP, FLARE = 0.25, 9\n",
       "look-minimal: the room for a spark's flare reaches past the panel's edge",
       expect="outside the panel", script=S)

mutate(MIN,
       "\t\tf:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", (TICK_X + inside - SPARK_HEAD * SPARK_W) * k, -under)\n",
       "\t\tf:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", 0, -under)\n",
       "look-minimal: the sparks start three quarters of their length along the line",
       expect="a spark's head rests at", script=S)

mutate(MIN,
       "\t\tf:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", (TICK_X + inside - SPARK_HEAD * SPARK_W) * k, -under)\n",
       "\t\tf:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", (TICK_X + inside - SPARK_HEAD * SPARK_W) * k, 0)\n",
       "look-minimal: the sparks ride half a spark over the hairline",
       expect="a spark does not ride the hairline", script=S)

# The sparks that fade in standing still, on the tick itself: the cut, now at
# the tick, would shear the head's halo there.
mutate(MIN,
       "\t\tlocal inside = f == self.spark and 0 or START_IN\n",
       "\t\tlocal inside = 0\n",
       "look-minimal: the owed spark and the glint fade in on the tick, their halo sheared by the cut",
       expect="a spark's head rests at", script=S)

# The hairline laid at half its caps' height, as it was first built (a file of
# its own height): the client rounds pieces of two heights to the screen apart.
mutate(MIN,
       "\tb[2]:SetHeight(tall)\n",
       "\tb[2]:SetHeight(tall / 2)\n",
       "look-minimal: the hairline laid at half its caps' height",
       expect="not one height", script=S)

mutate(MIN,
       "\tself.dash.run:SetOffset(run, 0)\n",
       "\tself.dash.run:SetOffset(roam, 0)\n",
       "look-minimal: a landing's dash stops short of the far tick",
       expect="not from tick to tick", script=S)

mutate(MIN,
       "\t\tf.tex = tex(f, \"Spark\", \"BLEND\", 2)\n",
       "\t\tf.tex = tex(f, \"Spark\", \"ADD\", 2)\n",
       "look-minimal: a spark that loops drawn additive",
       expect="a spark that loops is additive", script=S)

# --- nothing grows, nothing over the text ---

mutate(MIN,
       "\tlocal a = group:CreateAnimation(\"Translation\")\n",
       "\tlocal a = group:CreateAnimation(\"Scale\")\n",
       "look-minimal: the fill grown by a scale, not slid",
       expect="look-minimal: nothing grows", script=S)

mutate(MIN,
       "\t\tf:SetFrameLevel(base + level)\n",
       "\t\tf:SetFrameLevel(base + level + 6)\n",
       "look-minimal: the line's light drawn over the letters",
       expect="level with the text or over it", script=S)

# --- put on and taken off ---

mutate("Manners.toc",
       "Looks\\MinimalDress.lua\n",
       "",
       "look-minimal: the toc does not load the dressing",
       expect="look-minimal: the art is there", script=S)

mutate(MIN,
       "\tif p.minimalLine == false then\n",
       "\tif false then\n",
       "look-minimal: the line's switch reads nothing",
       expect="with the line switched off a piece of Minimal's is still drawn", script=S)

mutate(MIN,
       "\tself.flow:StopAll()\n\tfor _, g in ipairs(self.anims) do g:Stop() end\n\tself.frame:Hide()\n",
       "\tself.flow:StopAll()\n\tself.frame:Hide()\n",
       "look-minimal: the loops run on under a line switched off",
       expect="an animation of Minimal's still plays", script=S)

mutate(MIN,
       "\tfor _, g in ipairs(self.anims) do g:Stop() end\n\tself.frame:Hide()\n",
       "\tfor _, g in ipairs(self.anims) do g:Stop() end\n",
       "look-minimal: the line stays up when it is taken off",
       expect="a piece of Minimal's is still drawn", script=S)

mutate("Prompt/Panel.lua",
       "\tif S.dress and S.dress ~= dress then S.dress:Hide() end\n",
       "",
       "look-minimal: another look still wears Minimal's line",
       expect="on framed a piece of Minimal's is still drawn", script=S)

# --- at rest ---

mutate(MIN,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-minimal: the glint crosses the line on Calm",
       expect="on Calm 1 of Minimal's loops run", script=S)

mutate(MIN,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-minimal: the glint crosses the line in a fight",
       expect="in a fight 1 of Minimal's loops run", script=S)

mutate(MIN,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-minimal: the glint runs on with the prompt down",
       expect="with the prompt down", script=S)

mutate(MIN,
       "\tself.idle[#self.idle + 1] = self.drift\n",
       "",
       "look-minimal: the glint at rest loops unnamed",
       expect="what loops at rest is not named", script=S)

mutate(MIN,
       "\tself.drift.run:SetOffset(roam, 0)\n",
       "\tself.drift.run:SetOffset(wide, 0)\n",
       "look-minimal: the glint runs past the far tick",
       expect="the glint runs", script=S)

mutate(MIN,
       "local DRIFT = { hold = 0.8, up = 0.3, run = 1.9, down = 0.5, rest = 1.8, peak = 0.5 }",
       "local DRIFT = { hold = 0.1, up = 0.3, run = 1.9, down = 0.5, rest = 0.1, peak = 0.5 }",
       "look-minimal: the glint at rest never lets the line alone",
       expect="the glint comes round every", script=S)

# --- somebody owed ---

mutate(MIN,
       "\t\tReplay(self.fillIn)\n\t\tReplay(self.cast)\n",
       "\t\tReplay(self.cast)\n",
       "look-minimal: a favour sends the spark along a line that does not fill",
       expect="did not cast the line", script=S)

mutate(MIN,
       "\tif full and (isNew or not was) and not self.sputter:IsPlaying() then\n",
       "\tif full and not self.sputter:IsPlaying() then\n",
       "look-minimal: the line cast again at every scan",
       expect="cast again on a repaint", script=S)

mutate(MIN,
       "\tself.fillIn.away:SetOffset(-wide, 0)\n",
       "\tself.fillIn.away:SetOffset(0, 0)\n",
       "look-minimal: the fill slides out to the right instead of in",
       expect="does not slide in from a line's length away", script=S)

mutate(MIN,
       "\tAlpha(fillIn, 0, 0, CAST_LEAD, 1)\n",
       "\tAlpha(fillIn, 1, 1, CAST_LEAD, 1)\n",
       "look-minimal: the whole line seen jumping away before it is cast",
       expect="the fill is seen leaving before it is cast", script=S)

mutate(MIN,
       "\tcast.run = Slide(cast, CAST, 2, \"OUT\")\n",
       "\tcast.run = Slide(cast, CAST, 2, \"IN\")\n",
       "look-minimal: the spark lags the fill it leads",
       expect="do not move as one", script=S)

mutate(MIN,
       "\tself.cast.away:SetOffset(-2 * TICK_X * k, 0)\n",
       "\tself.cast.away:SetOffset(0, 0)\n",
       "look-minimal: the spark runs two ticks ahead of the fill",
       expect="does not ride the fill's leading end", script=S)

mutate(MIN,
       "\t\tif self.active and self.kit.FullEffects() then Replay(self.pinged) end\n",
       "",
       "look-minimal: the far tick lets the spark go by",
       expect="the far tick did not catch the spark", script=S)

mutate(MIN,
       "\tself.ping:SetPoint(\"BOTTOMRIGHT\", box, \"BOTTOMRIGHT\", 0, 0)\n",
       "\tself.ping:SetPoint(\"BOTTOMLEFT\", box, \"BOTTOMLEFT\", 0, 0)\n",
       "look-minimal: the near tick flashes as the spark reaches the far one",
       expect="the flash is not on the far tick", script=S)

mutate(MIN,
       "\tPark(fillIn, fill, level)\n",
       "\tPark(fillIn, fill, REST)\n",
       "look-minimal: the cast over, the line drops back to rest",
       expect="the cast over, the lit line is at", script=S)

mutate(MIN,
       "\t\tif not self.breath:IsPlaying() then self.breath:Play() end\n",
       "",
       "look-minimal: the owed line holds its breath",
       expect="the owed line does not breathe", script=S)

mutate(MIN,
       "\t\tColour(self.glow, r, g, b, self.owed and GLOW or 0)\n",
       "\t\tColour(self.glow, r, g, b, 0)\n",
       "look-minimal: the owed line never glows",
       expect="does not glow in the owed colour", script=S)

mutate(MIN,
       "\tself.patrol.run:SetOffset(roam, 0)\n",
       "\tself.patrol.run:SetOffset(wide, 0)\n",
       "look-minimal: the owed spark runs past the far tick",
       expect="the spark does not run from tick to tick", script=S)

mutate(MIN,
       "\tif not r or self.mode == \"off\" then r, g, b = WARM[1], WARM[2], WARM[3] end\n",
       "\tif not r then r, g, b = WARM[1], WARM[2], WARM[3] end\n",
       "look-minimal: the line wears the reason with the marker off",
       expect="with the marker off the line still wears", script=S)

mutate(MIN,
       "\tif full and flashStyle == \"pulse\" then\n\t\tif not self.breath:IsPlaying()",
       "\tif flashStyle == \"pulse\" then\n\t\tif not self.breath:IsPlaying()",
       "look-minimal: the owed line breathes on Calm",
       expect="on Calm something of Minimal's moves", script=S)

mutate(MIN,
       "\tif full and flashStyle == \"pulse\" then\n\t\tif not self.breath:IsPlaying()",
       "\tif full then\n\t\tif not self.breath:IsPlaying()",
       "look-minimal: Flash once loops as Pulse does",
       expect="on Flash once the owed loops run", script=S)

mutate(MIN,
       "\tif flashStyle == \"off\" or self.combat or not self.active then\n",
       "\tif self.combat or not self.active then\n",
       "look-minimal: the line lit for a favour with Flash off",
       expect="with Flash off the owed line is lit", script=S)

mutate(MIN,
       "\t\tStop(self.breath)\n\t\tStop(self.patrol)\n\t\tif not (self.sputter:IsPlaying() or self.back:IsPlaying()) then self.fill:SetAlpha(REST) end\n",
       "\t\tif not (self.sputter:IsPlaying() or self.back:IsPlaying()) then self.fill:SetAlpha(REST) end\n",
       "look-minimal: the owed loops run on with nobody owed",
       expect="the owed loops run on", script=S)

mutate(MIN,
       "\t\tif not (self.sputter:IsPlaying() or self.back:IsPlaying()) then self.fill:SetAlpha(REST) end\n\t\tself:Recolour()\n",
       "\t\tself:Recolour()\n",
       "look-minimal: the line stays at full with nobody owed",
       expect="nobody owed, and the line stays at", script=S)

mutate(MIN,
       "\tPark(breath, clip, 1)\n",
       "\tPark(breath, clip, BREATH_LO)\n",
       "look-minimal: the breath leaves the line at its low",
       expect="the breath left the line dimmed", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:Attention(isNew, arrived and not self:OutcomeLive(), mode) end\n",
       "",
       "look-minimal: a favour never reaches what Minimal wears",
       expect="did not cast the line", script=S)

# --- a landing ---

mutate(MIN,
       "\t\tStop(self.fillIn)\n\t\tStop(self.cast)\n\t\tReplay(self.dash)\n",
       "\t\tStop(self.cast)\n\t\tReplay(self.dash)\n",
       "look-minimal: a landing leaves the line half cast",
       expect="a landing left the line half cast", script=S)

mutate(MIN,
       "\t\tReplay(self.flash)\n",
       "",
       "look-minimal: a landing does not flash the line",
       expect="did not dash the line and flash it", script=S)

mutate(MIN,
       "\t\tReplay(self.flash)\n\t\tself:Strike(false)\n",
       "\t\tReplay(self.flash)\n\t\tself:Strike(true)\n",
       "look-minimal: a landing strikes the cross",
       expect="a landing's mark is not the tick", script=S)

mutate(MIN,
       "\tif not self.showIcon then return end\n",
       "",
       "look-minimal: the mark struck with no icon to strike",
       expect="with the icon off the mark is struck onto nothing", script=S)

mutate(MIN,
       "local HOT, HOT_UP, HOT_DOWN = 0.85, 0.06, 0.44",
       "local HOT, HOT_UP, HOT_DOWN = 0.85, 0.06, 0.74",
       "look-minimal: the line's additive flash outstays 0.6 s",
       expect="a landing's light lasts", script=S)

mutate(MIN,
       "\tself.checkSheet = flow:Sheet(self.check, MARK_COLS, MARK_ROWS, MARK_FRAMES, MARK_FPS, false)\n",
       "\tself.checkSheet = flow:Sheet(self.check, MARK_COLS, MARK_ROWS, MARK_FRAMES, MARK_FPS, true)\n",
       "look-minimal: the tick struck over and over",
       expect="played once", script=S)

mutate(MIN,
       "local MARK_COLS, MARK_ROWS, MARK_FRAMES = 4, 2, 8",
       "local MARK_COLS, MARK_ROWS, MARK_FRAMES = 4, 2, 6",
       "look-minimal: the tick stops two frames short of the mark",
       expect="the tick's sheet is not eight frames", script=S)

mutate(MIN,
       "\t\tself.badge:SetPoint(\"CENTER\", kit.icon, \"BOTTOMRIGHT\", -p.iconSize * MARK_IN, p.iconSize * MARK_IN)\n",
       "\t\tself.badge:SetPoint(\"CENTER\", kit.icon, \"CENTER\", 0, 0)\n",
       "look-minimal: the mark struck across the middle of the icon",
       expect="the mark is not on the icon's lower right corner", script=S)

mutate(MIN,
       "\tif self.combat or not self.active then return end\n\tif kind == \"cast\" then\n",
       "\tif not self.active then return end\n\tif kind == \"cast\" then\n",
       "look-minimal: a landing plays its gesture in a fight",
       expect="in a fight a landing still plays", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:Flourish(kind) end\n",
       "",
       "look-minimal: an outcome never reaches what Minimal wears",
       expect="a landing did not dash the line", script=S)

# --- a refusal ---

mutate(MIN,
       "\t\tfor _, t in ipairs(self.fillBar) do Colour(t, BREAK[1], BREAK[2], BREAK[3]) end\n\t\tColour(self.glow, BREAK",
       "\t\tColour(self.glow, BREAK",
       "look-minimal: a refused line keeps the reason's colour",
       expect="of a refused line is not red", script=S)

mutate(MIN,
       "\t\tself.sputter:Play()\n\t\tself:Strike(true)\n",
       "\t\tself.sputter:Play()\n\t\tself:Strike(false)\n",
       "look-minimal: a refusal strikes the tick",
       expect="a refusal did not strike the cross", script=S)

mutate(MIN,
       "\tself.sputter.out:SetOffset(-wide, 0)\n",
       "\tself.sputter.out:SetOffset(wide, 0)\n",
       "look-minimal: a refused line runs on out to the right",
       expect="does not run back out the way it was cast", script=S)

mutate(MIN,
       "\tif not self.broken then\n",
       "\tif true then\n",
       "look-minimal: a repaint takes the red off a line still sputtering",
       expect="a repaint took the red off", script=S)

mutate(MIN,
       "\tsputter:SetScript(\"OnFinished\", function()\n\t\tself.broken = nil\n\t\tself:Recolour()\n",
       "\tsputter:SetScript(\"OnFinished\", function()\n\t\tself.broken = nil\n",
       "look-minimal: the line stays red after its sputter",
       expect="the sputter over, piece", script=S)

mutate(MIN,
       "\t\tback.fade:SetToAlpha(level())\n\t\tReplay(back)\n",
       "\t\tback.fade:SetToAlpha(level())\n",
       "look-minimal: the line never comes back after a refusal",
       expect="did not fade back in after the sputter", script=S)

mutate(MIN,
       "\tPark(back, fill, level)\n",
       "\tPark(back, fill, 0)\n",
       "look-minimal: the line fades back in and goes out",
       expect="the line came back at", script=S)

mutate(MIN,
       "\tsputter:SetScript(\"OnStop\", function()\n\t\tself.broken = nil\n\t\tself:Recolour()\n",
       "\tsputter:SetScript(\"OnStop\", function()\n\t\tself.broken = nil\n",
       "look-minimal: a refusal cut short leaves the line red",
       expect="a refusal cut short left the line red", script=S)

mutate(MIN,
       "\tStop(self.back)\n\tStop(self.stamp)\n",
       "\tStop(self.back)\n",
       "look-minimal: the cross stays on the icon over the next person",
       expect="play on after a repaint stopped them", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:StopFlourishes() end\n",
       "",
       "look-minimal: a repaint about somebody else leaves Minimal's refusal playing",
       expect="a refusal cut short left the line red", script=S)

mutate(MIN,
       "local TICK_COLOUR, CROSS_COLOUR = { 0.66, 0.97, 0.66 }, { 1.00, 0.52, 0.44 }",
       "local TICK_COLOUR, CROSS_COLOUR = { 1.00, 0.52, 0.44 }, { 0.66, 0.97, 0.66 }",
       "look-minimal: a red tick and a green cross",
       expect="the tick is not green", script=S)

# --- one alpha ---

mutate(MIN,
       "\t\tColour(self.glow, r, g, b, self.owed and GLOW or 0)\n",
       "\t\tself.glow:SetAlpha(self.owed and GLOW or 0)\n\t\tself.glow:SetVertexColor(r, g, b)\n",
       "look-minimal: the glow dimmed and then coloured, at full strength in the game",
       expect="look-minimal: a colour never moves a texture's alpha", script=S)

mutate(MIN,
       "\tfor _, t in ipairs(self.hotBar) do Colour(t, hr, hg, hb) end\n",
       "\tfor _, t in ipairs(self.hotBar) do t:SetVertexColor(hr, hg, hb, 0.5) end\n",
       "look-minimal: the flash's colour given an alpha of its own",
       expect="look-minimal: a colour never moves a texture's alpha", script=S)
