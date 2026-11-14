# Mutations for the Ebon look (Looks/Ebon.lua, Manners.toc,
# tools/make_ebon_textures.py): registered and loaded, the icon cut to the
# socket whatever the switch says, the marker's carriers and the runeforge's
# cold blue, the vapour cut to its bands, the runes kindled one after another
# with a light on the edge, the soulfire taller and quicker for somebody owed,
# the three breaths, the runeforge, its sparks and the runes' flashes, the
# refusal's guttering, snuffed fire, notch and dull steel and the lighting
# after, the vapour out of a list hung on either side and the list right of
# the guard, no additive light at rest, the blade alive only at rest on Full
# with the prompt up, Calm, a fight, the words past the guard and the tags
# left of the runes, the words' contrast and the reason line's shadow, a name
# measured once, a colour that leaves every alpha alone, and the Lua and the
# generator agreeing. Each is caught by the scenario in
# tests/scenarios/look-ebon.lua that names it.

S = "runscenarios.py"

# --- registered ---

mutate("Manners.toc",
       "Looks\\Frost.lua\nLooks\\Ebon.lua\n",
       "Looks\\Frost.lua\n",
       "look-ebon: the toc does not load the look",
       expect="look-ebon: it is registered and loaded after the other looks", script=S)

mutate("Looks/Ebon.lua",
       "\torder = 9.9,\n",
       "\torder = 11,\n",
       "look-ebon: after Glass in the picker",
       expect="ebon is not after Frost and before Glass", script=S)

mutate("Looks/Ebon.lua",
       "\tcombatArtAlpha = 1,\n\tclassSoften = 0.5,\n\t-- The words stand on the blued steel whatever the panel colour says.\n",
       "\tclassSoften = 0.5,\n\t-- The words stand on the blued steel whatever the panel colour says.\n",
       "look-ebon: the art dimmed twice in a fight",
       expect="Prompt is told to dim the art as well", script=S)

# --- the socket's eight sides, and Hide ---

mutate("Looks/Ebon.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-ebon: the cooldown swept square over the socket",
       expect="the cooldown's sweep is not cut to the socket", script=S)

mutate("Looks/Ebon.lua",
       "\tif showIcon then\n\t\tif not self.masked then\n\t\t\ticon:AddMaskTexture(self.mask)\n\t\t\tself.masked = true\n\t\tend\n",
       "\tif showIcon and self.p.roundIcon then\n\t\tif not self.masked then\n\t\t\ticon:AddMaskTexture(self.mask)\n\t\t\tself.masked = true\n\t\tend\n",
       "look-ebon: a square icon in the eight-sided socket with the switch off",
       expect="the icon wears no mask with Round the icon off off", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-ebon: the eight-sided mask left on the next look's icon",
       expect="look-ebon: every state paints on", script=S)

mutate("Looks/Ebon.lua",
       "\tself.active = nil\n\tself.flow:StopAll()\n",
       "\tself.active = nil\n",
       "look-ebon: the soulfire still burning under the next look",
       expect="under another look, still running", script=S)

mutate("Looks/Ebon.lua",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.vapourMask[1]:Hide()\n\tself.vapourMask[2]:Hide()\n",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "look-ebon: the vapour's masks left shown under the next look",
       expect="the vapour's masks are still shown under another look", script=S)

mutate("Looks/Ebon.lua",
       "\tfor _, t in ipairs({ self.flame, self.heart, self.guard, self.socket,",
       "\tfor _, t in ipairs({ self.heart, self.socket,",
       "look-ebon: the guard and its soulfire drawn with the icon off",
       expect="with the icon off the guard, its soulfire, its light or the forge are still drawn", script=S)

# --- the marker ---

mutate("Looks/Ebon.lua",
       "\tif not ring then cr, cg, cb = RUNEFROST[1], RUNEFROST[2], RUNEFROST[3] end\n",
       "",
       "look-ebon: the soulfire coloured with the marker on the stripe",
       expect="the soulfire is coloured", script=S)

mutate("Looks/Ebon.lua",
       "\tif not stripe then vr, vg, vb = RUNEFROST[1], RUNEFROST[2], RUNEFROST[3] end\n",
       "",
       "look-ebon: the runes coloured with the marker on the icon",
       expect="rune 1 is coloured", script=S)

mutate("Looks/Ebon.lua",
       "\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\nend\n\n-- Whether a stored colour",
       "\treturn true, mode == \"stripe\" or mode == \"both\"\nend\n\n-- Whether a stored colour",
       "look-ebon: the options told the socket always carries the reason",
       expect="AccentCarriers says true", script=S)

mutate("Looks/Ebon.lua",
       "\t\tColour(self.runeGlow[i], vr, vg, vb)\n",
       "\t\tColour(self.runeGlow[i], cr, cg, cb)\n",
       "look-ebon: a rune's light in the socket's colour",
       expect="is not the rune's colour", script=S)

mutate("Looks/Ebon.lua",
       "\t\tt:AddMaskTexture(self.vapourMask[i <= 2 and 1 or 2])\n",
       "",
       "look-ebon: the vapour drawn as a sheet over the whole band's box",
       expect="of the vapour is not cut to its edge's band", script=S)

# --- a favour arriving ---

mutate("Looks/Ebon.lua",
       "\t\t\tself:Breath()\n\t\t\tPlayAll(self.arrive)\n",
       "\t\t\tself:Breath()\n",
       "look-ebon: a favour arriving kindles nothing",
       expect="no light ran the upper edge as the favour arrived", script=S)

mutate("Looks/Ebon.lua",
       "\t\tlocal wait = 0.06 + KINDLE_STEP * (i - 1)\n",
       "\t\tlocal wait = 0.06\n",
       "look-ebon: the three runes kindled at once",
       expect="no later than the one before it", script=S)

mutate("Looks/Ebon.lua",
       "\tself.runAnim.move:SetOffset(math.max(0, span), 0)\n",
       "\tself.runAnim.move:SetOffset(0, 0)\n",
       "look-ebon: the light on the edge stands where it was lit",
       expect="the light runs 0.0 of an edge", script=S)

mutate("Looks/Ebon.lua",
       "\tif isNew then\n\t\tself.pulseSpent, self.calmLit = nil, nil\n\t\t-- The runes kindle for a new favour, never a new face.\n\t\tif full and self.runesOK then\n",
       "\tdo\n\t\tself.pulseSpent, self.calmLit = nil, nil\n\t\t-- The runes kindle for a new favour, never a new face.\n\t\tif full and self.runesOK then\n",
       "look-ebon: every repaint kindles the runes again",
       expect="a repaint kindled the runes again", script=S)

# --- owed ---

mutate("Looks/Ebon.lua",
       "\tlocal h = self.flameH * (owed and FLAME.owed or 1)\n",
       "\tlocal h = self.flameH\n",
       "look-ebon: the soulfire no taller for somebody owed",
       expect="owed, the soulfire is no taller", script=S)

mutate("Looks/Ebon.lua",
       "\tself.flameSheet.fps = owed and FLAME.quick or FLAME.fps\n",
       "\tself.flameSheet.fps = FLAME.fps\n",
       "look-ebon: the soulfire no quicker for somebody owed",
       expect="owed, the soulfire burns no quicker", script=S)

mutate("Looks/Ebon.lua",
       "\t\tif alive and self.runesOK and not self.owed then\n",
       "\t\tif alive and self.runesOK then\n",
       "look-ebon: the chase runs over runes that stand lit",
       expect="still takes its turn in the chase", script=S)

mutate("Looks/Ebon.lua",
       "\t\t\tEbon.pulseSpent = true\n\t\t\tif Ebon.pulse[1]:IsPlaying() then\n\t\t\t\tEbon:HoldPulse(true)\n",
       "\t\t\tEbon.pulseSpent = true\n\t\t\tif false then\n\t\t\t\tEbon:HoldPulse(true)\n",
       "look-ebon: the breath never stops",
       expect="after three breaths, breath 1 still loops", script=S)

mutate("Looks/Ebon.lua",
       "\tself.flame = tex(art, \"ARTWORK\", -8, \"Flame\")\n",
       "\tself.flame = tex(art, \"ARTWORK\", -1, \"Flame\")\n",
       "look-ebon: the soulfire drawn over the skull",
       expect="the soulfire is drawn over the skull", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal was = self.owed\n\tself.owed = nil\n\tif was then self:Breath() end\n",
       "\tself.owed = nil\n",
       "look-ebon: the runes left lit when nobody is owed any more",
       expect="with nobody owed any more rune 1 is at", script=S)

# --- a landing ---

mutate("Looks/Ebon.lua",
       "\t\tself.forgeAnim:Stop()\n\t\tself.forgeAnim:Play()\n\t\tself.forgeSheet:Play()\n",
       "\t\tself.forgeAnim:Stop()\n\t\tself.forgeAnim:Play()\n",
       "look-ebon: the runeforge shown on its first frame only",
       expect="a landing did not play the runeforge's frames", script=S)

mutate("Looks/Ebon.lua",
       "\tself.forgeSheet = flow:Sheet(self.forge, FORGE_COLS, FORGE_ROWS, FORGE_FRAMES, FORGE_FPS, false)\n",
       "\tself.forgeSheet = flow:Sheet(self.forge, FORGE_COLS, FORGE_ROWS, FORGE_FRAMES, FORGE_FPS, true)\n",
       "look-ebon: the runeforge's frames over and over",
       expect="the runeforge's sheet loops", script=S)

mutate("Looks/Ebon.lua",
       "\tif self.runesOK then PlayAll(self.strike) end\n",
       "",
       "look-ebon: a landing leaves the runes as they were",
       expect="a landing did not flash rune 1", script=S)

mutate("Looks/Ebon.lua",
       "\tPlayAll(self.sparkAnims)\n\tself.tipAnim:Stop()\n\tself.tipAnim:Play()\n",
       "\tself.tipAnim:Stop()\n\tself.tipAnim:Play()\n",
       "look-ebon: a landing throws no sparks",
       expect="a landing threw 0 sparks", script=S)

mutate("Looks/Ebon.lua",
       "\tAt(self.forge, art, cx, cy, circle)\n",
       "\tAt(self.forge, art, cx, cy, circle * 2)\n",
       "look-ebon: the runeforge drawn across the words",
       expect="the runeforge does not lie over the guard and no more", script=S)

mutate("Looks/Ebon.lua",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n\tif kind ~= \"cast\" then return end\n",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n",
       "look-ebon: the runeforge struck for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Ebon.lua",
       "\tself.forge = tex(self.lightFrame, \"OVERLAY\", 1, \"Forge\")\n",
       "\tself.forge = tex(self.lightFrame, \"OVERLAY\", 1, \"Forge\", \"ADD\")\n",
       "look-ebon: the runeforge's sheet additive for half a second",
       expect="the runeforge's sheet is additive", script=S)

# --- a refusal ---

mutate("Looks/Ebon.lua",
       "\t\t\tif self.runesOK then\n\t\t\t\tPlayAll(self.gutter)\n\t\t\t\tPlayAll(self.aftermath)\n\t\t\tend\n",
       "\t\t\tif self.runesOK then\n\t\t\t\tPlayAll(self.aftermath)\n\t\t\tend\n",
       "look-ebon: the runes of a refused blade go out without guttering",
       expect="a refusal did not gutter rune 1", script=S)

mutate("Looks/Ebon.lua",
       "\t\tself.gutter[i] = anim(Gutter(self.runes[i], 0.06 * (#RUNE_AT - i)))\n",
       "\t\tself.gutter[i] = anim(Gutter(self.runes[i], 0.06 * (i - 1)))\n",
       "look-ebon: the runes gutter guard to point, as they kindled",
       expect="gutters no sooner than the one nearer the guard", script=S)

mutate("Looks/Ebon.lua",
       "\tif dead then\n\t\tflame, eyes, rune = 0, 0, 0\n",
       "\tif dead then\n\t\tflame, eyes, rune = 0, 0, RUNE.rest\n",
       "look-ebon: a refused blade's runes still lit",
       expect="a refused blade's runes are still lit", script=S)

mutate("Looks/Ebon.lua",
       "\tif not self.notchIn:IsPlaying() then self.notch:SetAlpha(NOTCH_HELD) end\n",
       "",
       "look-ebon: a refusal on Calm leaves no notch",
       expect="on Calm a refused blade has no notch", script=S)

mutate("Looks/Ebon.lua",
       "\tColour(self.socket, SPENT[1], SPENT[2], SPENT[3])\n\tself.halo:SetAlpha(0)\n",
       "\tself.halo:SetAlpha(0)\n",
       "look-ebon: a refused blade's socket keeps the reason's light",
       expect="a refusal did not leave the socket's light spent", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal alive = on and not self.refused\n\tlocal icon = self.kit.icon:IsShown()\n\tself:Stoke()\n",
       "\tlocal alive = on\n\tlocal icon = self.kit.icon:IsShown()\n\tself:Stoke()\n",
       "look-ebon: the soulfire burns on over a blade put out",
       expect="after a refusal", script=S)

mutate("Looks/Ebon.lua",
       "\tself.notchIn:Stop()\n\tself.notch:SetAlpha(0)\n\tStopAll(self.gutter)\n",
       "\tself.notchIn:Stop()\n\tStopAll(self.gutter)\n",
       "look-ebon: the notch left in a blade lit again",
       expect="after the refusal the notch stays", script=S)

mutate("Looks/Ebon.lua",
       "\t\tlocal lit = not self.refused\n\t\tself.refused = true\n",
       "\t\tlocal lit = true\n\t\tself.refused = true\n",
       "look-ebon: a blade already out gutters again at every refusal",
       expect="a blade already out guttered its runes again", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal nh = ph * 0.42\n",
       "\tlocal nh = ph * 1.3\n",
       "look-ebon: the notch struck down through the reason line",
       expect="the notch reaches past the blade's middle", script=S)

# --- the list ---

mutate("Looks/Ebon.lua",
       "\t\tif list and ((i <= 2 and not at) or (i > 2 and at)) then a = 0 end\n",
       "",
       "look-ebon: the vapour lies over the list",
       expect="of the vapour rolls into the list under the blade", script=S)

mutate("Looks/Ebon.lua",
       "\t\tlocal hung = self.listShown and ((i <= 2 and not self.listAt) or (i > 2 and self.listAt))\n",
       "\t\tlocal hung = self.listShown and (i <= 2 and not self.listAt)\n",
       "look-ebon: the upper vapour still rolls under a list hung over the blade",
       expect="of the vapour rolls into the list over the blade", script=S)

mutate("Looks/Ebon.lua",
       "\tself.listX0 = showIcon and (discRight - 1) or (plateX + 2)\n",
       "\tself.listX0 = plateX + 2\n",
       "look-ebon: the list begins under the guard's fangs",
       expect="under a guard whose socket reaches", script=S)

mutate("Looks/Ebon.lua",
       "\t\tlocal away = (i <= 2) and -1 or 1\n",
       "\t\tlocal away = -1\n",
       "look-ebon: the vapour over the blade sinks into it",
       expect="the vapour drifts the same way off both edges", script=S)

# --- no additive light at rest ---

mutate("Looks/Ebon.lua",
       "\tself.hotAnim = anim(Flash(self.hot, 0.80, 0.05, 0.30, 0))\n",
       "\tself.hotAnim = anim(Flash(self.hot, 0.80, 0.05, 0.30, 0.4))\n",
       "look-ebon: the socket left white-hot after a landing",
       expect="additive light left on", script=S)

mutate("Looks/Ebon.lua",
       "\t\tself.runeLit[i] = tex(art, \"BORDER\", 4, RUNE_FILES[i])\n",
       "\t\tself.runeLit[i] = tex(art, \"BORDER\", 4, RUNE_FILES[i], \"ADD\")\n",
       "look-ebon: the chase's light additive, at rest",
       expect="a light that rests lit is additive", script=S)

mutate("Looks/Ebon.lua",
       "\t\tself.strike[i] = anim(Flash(self.runeHot[i], 0.90, 0.05, 0.28, 0, 0.05 + 0.06 * (i - 1)))\n",
       "\t\tself.strike[i] = anim(Flash(self.runeHot[i], 0.90, 0.05, 0.68, 0, 0.05 + 0.06 * (i - 1)))\n",
       "look-ebon: a rune's white heat lit for three quarters of a second",
       expect="the landing's light", script=S)

# --- alive at rest ---

mutate("Looks/Ebon.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-ebon: the soulfire burns and the runes chase on Calm",
       expect="on Calm, still running", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-ebon: the soulfire burns and the runes chase in a fight",
       expect="in a fight, still running", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-ebon: the look runs on under a prompt that is down",
       expect="with the prompt down, still running", script=S)

mutate("Looks/Ebon.lua",
       "\t-- Asked afresh: what moves may move elsewhere now.\n\tself.idleState = nil\n",
       "\t-- Asked afresh: what moves may move elsewhere now.\n",
       "look-ebon: a restyle that takes the runes away leaves the chase running",
       expect="is drawn or chases on a blade too short for its point", script=S)

mutate("Looks/Ebon.lua",
       "\t\tself.chase[i] = anim(Chase(t, CHASE[i], CHASE.rest - CHASE[i] + CHASE[1], CHASE.peak))\n",
       "\t\tself.chase[i] = anim(Chase(t, CHASE[i], CHASE.rest, CHASE.peak))\n",
       "look-ebon: the three runes of the chase drift out of step",
       expect="keeps a measure of", script=S)

mutate("Looks/Ebon.lua",
       "\tself.sheenAnims[2].move:SetOffset(-math.max(0, span - sw), 0)\n",
       "\tself.sheenAnims[2].move:SetOffset(math.max(0, span - sw), 0)\n",
       "look-ebon: the lower edge's sheen runs off the point",
       expect="not one each way along the blade", script=S)

mutate("Looks/Ebon.lua",
       "\tif name and not (entry.reason == \"owed\") then self:Greet() end\n",
       "",
       "look-ebon: nobody is greeted",
       expect="the first face on the panel was not greeted", script=S)

mutate("Looks/Ebon.lua",
       "\t\t\tself.flameSheet:Play()\n\t\t\tself.heartSheet:Play()\n",
       "\t\t\tself.flameSheet:Play()\n",
       "look-ebon: the soulfire's heart stands still inside a fire that burns",
       expect="the soulfire's heart", script=S)

# --- Calm, a fight ---

mutate("Looks/Ebon.lua",
       "\t\t\t-- Still: the first frame, whichever it stopped on.\n\t\t\tStill(self.flame, FLAME_COLS, FLAME_ROWS, 0)\n",
       "\t\t\t-- Still: the first frame, whichever it stopped on.\n\t\t\tStill(self.flame, FLAME_COLS, FLAME_ROWS, 3)\n",
       "look-ebon: on Calm the soulfire stands on whatever frame",
       expect="on Calm the soulfire does not stand on its first frame", script=S)

mutate("Looks/Ebon.lua",
       "\telseif fight then\n\t\tflame, eyes, rune = FLAME.combat, EYES.combat, RUNE.combat\n",
       "\telseif false then\n\t\tflame, eyes, rune = FLAME.combat, EYES.combat, RUNE.combat\n",
       "look-ebon: the runes and the soulfire at full strength in a fight",
       expect="not dimmed", script=S)

mutate("Looks/Ebon.lua",
       "\tself.guard:SetDesaturated(fight or dead)\n",
       "\tself.guard:SetDesaturated(dead)\n",
       "look-ebon: the guard keeps its colour in a fight",
       expect="in a fight the guard keeps its colour", script=S)

mutate("Looks/Ebon.lua",
       "\tkit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)\n",
       "\tkit.textLayer:SetAlpha(1)\n",
       "look-ebon: the words at full strength in a fight",
       expect="in a fight the words are not dimmed", script=S)

# --- the layout ---

mutate("Looks/Ebon.lua",
       "\tlocal textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP\n",
       "\tlocal textX = showIcon and (cx + TEXT_GAP) or BARE_GAP\n",
       "look-ebon: the words written over the socket",
       expect="under a socket that reaches", script=S)

mutate("Looks/Ebon.lua",
       "\tself.chipInset = math.ceil(W - rootX) + 2\n",
       "\tself.chipInset = 4\n",
       "look-ebon: the tags laid over the runes",
       expect="the tags would lie over the runes", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal cx, cy = circle * GUARD_HALF, H / 2\n",
       "\tlocal cx, cy = circle * 0.2, H / 2\n",
       "look-ebon: the socket hangs off the panel's left edge",
       expect="the socket passes the panel's left edge", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal need = (fs + 2 + sub + 4) / FACE\n",
       "\tlocal need = (fs + 2 + sub + 4) * 0.8\n",
       "look-ebon: the flat too low for two lines",
       expect="tall under two lines of", script=S)

mutate("Looks/Ebon.lua",
       "\t\tAt(t, art, cx + (i == 1 and -1 or 1) * circle * EYE_OUT, cy - circle * EYE_UP, math.max(3, circle * EYE_SIZE))\n",
       "\t\tAt(t, art, cx + (i == 1 and -1 or 1) * circle * EYE_OUT, cy, math.max(3, circle * EYE_SIZE))\n",
       "look-ebon: the eyes lit in the middle of the icon",
       expect="is not in the skull over the socket", script=S)

# --- the words ---

mutate("Looks/Ebon.lua",
       "\tsr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)\n",
       "",
       "look-ebon: the reason line in the reason's own colour, however dark",
       expect="the reason line reads at", script=S)

mutate("Looks/Ebon.lua",
       "\tlocal vr, vg, vb = kit.Legible(o[1], o[2], o[3], SUB_CONTRAST)\n",
       "\tlocal vr, vg, vb = o[1] * 0.4, o[2] * 0.4, o[3] * 0.4\n",
       "look-ebon: the verdict in a colour too dark for the steel",
       expect="the verdict of a", script=S)

mutate("Looks/Ebon.lua",
       "\tkit.sub:SetShadowColor(0, 0.01, 0.02, 1)\n",
       "\tkit.sub:SetShadowColor(0, 0.01, 0.02, 0.5)\n",
       "look-ebon: the reason line over half a shadow",
       expect="the reason line has no full dark shadow", script=S)

mutate("Looks/Ebon.lua",
       "\tink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)\n",
       "\tink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_LO)\n",
       "look-ebon: the words judged on a ground darker than the one drawn",
       expect="the look does not state the blued steel as the ground", script=S)

mutate("Looks/Ebon.lua",
       "\t\tif secret or text ~= self.measuredText or size ~= self.measuredSize then\n",
       "\t\tdo\n",
       "look-ebon: a name at its smallest measured at every scan",
       expect="look-ebon: a name at its smallest is measured once", script=S)

# --- one alpha ---

mutate("Looks/Ebon.lua",
       "\tColour(self.hot, wr, wg, wb)\n",
       "\tself.hot:SetVertexColor(wr, wg, wb, 1)\n",
       "look-ebon: a reason's colour lights the socket's white heat for good",
       expect="look-ebon: a colour leaves every light as faint as it was", script=S)

mutate("Looks/Ebon.lua",
       "\t\tColour(self.runeLit[i], lr, lg, lb)\n",
       "\t\tself.runeLit[i]:SetVertexColor(lr, lg, lb, 1)\n",
       "look-ebon: a reason's colour lights the chase's light for good",
       expect="look-ebon: a colour leaves every light as faint as it was", script=S)

mutate("Looks/Ebon.lua",
       "\t\tColour(self.guard, DULL[1], DULL[2], DULL[3])\n",
       "\t\tself.guard:SetVertexColor(DULL[1], DULL[2], DULL[3], 0.5)\n",
       "look-ebon: a fight's dulling writes over the guard's alpha",
       expect="look-ebon: a colour leaves every light as faint as it was", script=S)

# --- the Lua and the generator ---

mutate("Looks/Ebon.lua",
       "local END_W = 144\n",
       "local END_W = 160\n",
       "look-ebon: the point's length differs between the Lua and the generator",
       expect="END_W is 160 in the Lua and 144 in the generator", script=S)

mutate("Looks/Ebon.lua",
       "local RUNE_AT = { 32, 76, 108 }\n",
       "local RUNE_AT = { 32, 76, 112 }\n",
       "look-ebon: the third rune's light off its cut",
       expect="RUNE_AT[3] is 112 in the Lua", script=S)

mutate("tools/make_ebon_textures.py",
       "EYE_UP = 0.352         #",
       "EYE_UP = 0.30          #",
       "look-ebon: the skull's eyes drawn where the Lua does not light them",
       expect="EYE_UP is", script=S)

mutate("Looks/Ebon.lua",
       "\tself.notch = tex(art, \"BORDER\", 1, \"Notch\")\n",
       "\tself.notch = tex(art, \"BORDER\", 1, \"Crack\")\n",
       "look-ebon: the look asks for a file nobody draws",
       expect="the look draws Ebon_Crack, which the generator does not write", script=S)

mutate("Looks/Ebon.lua",
       "local RING_PEAK, RING_EDGE = 0.773, 0.914\n",
       "local RING_PEAK, RING_EDGE = 0.773, 0.80\n",
       "look-ebon: the rings held to less room than their art is seen in",
       expect="the ring file's line is at", script=S)

mutate("tools/make_ebon_textures.py",
       "SEED = 5113\n",
       "SEED = 5114\n",
       "look-ebon: the generator no longer draws the files that ship",
       expect="does not match the file that ships", script=S)
