# Mutations for the Wild look (Looks/Wild.lua, Looks/Looks.lua, Manners.toc,
# tools/make_wild_textures.py): registered and loaded, round whatever the
# switch says, the marker's carriers and moonlight's silver, the water cut to
# its ring, the vine grown half after half and bud after bud, the blossoms
# each at its own pace,
# the three breaths, the paw, the bloom, the leaves and the shed blossoms, the
# refusal, the vine and the list under a list hung over the panel, no
# additive light at rest, the wood alive only at rest on Full with the prompt
# up, Calm, a fight, the words past the wreath and the tags left of the
# crozier, the bough on a tall button, a name measured once, and the Lua and
# the generator agreeing. Each is caught by the scenario in
# tests/scenarios/look-wild.lua that names it (one by perf-budget.lua).

S = "runscenarios.py"

# --- registered ---

mutate("Looks/Looks.lua",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true, frost = true }\n",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true }\n",
       "look-wild: the round switch live on the wreath",
       expect="wild is not in roundAlways", script=S)

mutate("Manners.toc",
       "Looks\\Fel.lua\nLooks\\Wild.lua\n",
       "Looks\\Fel.lua\n",
       "look-wild: the toc does not load the look",
       expect="look-wild: it is registered, in the toc, and translated", script=S)

mutate("Looks/Wild.lua",
       "\torder = 9.7,\n",
       "\torder = 11,\n",
       "look-wild: after Glass in the picker",
       expect="wild is not after Fel and before Glass", script=S)

# --- round, and Hide ---

mutate("Looks/Wild.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-wild: the cooldown swept square over the wreath",
       expect="the cooldown's sweep is not cut round", script=S)

mutate("Looks/Wild.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-wild: the round mask left on the next look's icon",
       expect="look-wild: every state paints on", script=S)

mutate("Looks/Wild.lua",
       "\tself.active = nil\n\tself.flow:StopAll()\n",
       "\tself.active = nil\n",
       "look-wild: the water still rippling under the next look",
       expect="under another look, still running", script=S)

mutate("Looks/Wild.lua",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.waterMask:Hide()\n",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "look-wild: the water's mask left shown under the next look",
       expect="is still shown under another look", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.paw, self.bloom, self.glints[1], self.glints[2] }) do\n\t\tt:SetShown(showIcon)\n",
       "\t\tself.paw, self.bloom, self.glints[1], self.glints[2] }) do\n\t\tt:SetShown(true)\n",
       "look-wild: a wreath round an icon that is off",
       expect="with the icon off the wreath", script=S)

# --- the marker ---

mutate("Looks/Wild.lua",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "look-wild: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate("Looks/Wild.lua",
       "\tif not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end\n",
       "",
       "look-wild: the water coloured whatever the marker",
       expect="the water is coloured", script=S)

mutate("Looks/Wild.lua",
       "\tself.moon:SetVertexColor(vr, vg, vb, 1)\n",
       "\tself.moon:SetVertexColor(r, g, b, 1)\n",
       "look-wild: the moon coloured whatever the marker",
       expect="the moon is coloured", script=S)

mutate("Looks/Wild.lua",
       "\tself.inlay:SetVertexColor(vr, vg, vb, INLAY_ALPHA)\n",
       "\tself.inlay:SetVertexColor(cr, cg, cb, INLAY_ALPHA)\n",
       "look-wild: the inlay coloured by the icon's marker",
       expect="the inlay is", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.water[i]:AddMaskTexture(self.waterMask)\n",
       "",
       "look-wild: the water a square under the wreath",
       expect="is not cut to the bed's ring", script=S)

# --- the vine ---

mutate("Looks/Wild.lua",
       "\t\t\tself.vines[2]:SetAlpha(0)\n\t\t\tself.vineSheets[1]:Play()\n",
       "\t\t\tself.vines[2]:SetAlpha(0)\n",
       "look-wild: a vine that comes whole",
       expect="a favour arriving did not play the vine's frames", script=S)

mutate("Looks/Wild.lua",
       "\t\t\tPlayAll(self.arrive)\n\t\t\t-- The first half grows; the second waits for it, unseen.\n",
       "\t\t\t-- The first half grows; the second waits for it, unseen.\n",
       "look-wild: a favour arriving brings no vine",
       expect="a favour arriving did not bring the vine", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.vineSheets[i] = flow:Sheet(t, VINE_COLS, VINE_ROWS, VINE_FRAMES, VINE_FPS, false)\n",
       "\t\tself.vineSheets[i] = flow:Sheet(t, VINE_COLS, VINE_ROWS, VINE_FRAMES, VINE_FPS, true)\n",
       "look-wild: a vine that grows over and over",
       expect="the vine's frames loop", script=S)

mutate("Looks/Wild.lua",
       "\t\t\tself.vineSheets[2]:Stop()\n\t\t\tself.vines[2]:SetAlpha(0)\n",
       "\t\t\tself.vineSheets[2]:Stop()\n",
       "look-wild: the vine's far half out before its near half has grown",
       expect="the vine's second half is out before its first has grown", script=S)

mutate("Looks/Wild.lua",
       "\t\tWild.vines[2]:SetAlpha(1)\n\t\tsecond:Play()\n",
       "\t\tWild.vines[2]:SetAlpha(1)\n",
       "look-wild: a vine that stops half way along the bough",
       expect="half way, the vine's second half is not growing", script=S)

mutate("Looks/Wild.lua",
       "\t\tsecond.t0 = first.t0 + first.frames / first.fps\n",
       "",
       "look-wild: the vine's far half timed from a late clock",
       expect="is timed from when the clock said so", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.idle[#self.idle + 1] = self.glintAnims[i]\n",
       "",
       "look-wild: the water's glints looping unnamed",
       expect="loop(s) kept going with nobody owed", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.budIn[i] = anim(Fade(t, 0, 1, 0.12, 0.10 + BLOSSOMS.at[i] * VINE_SECONDS))\n",
       "\t\tself.budIn[i] = anim(Fade(t, 0, 1, 0.12, 0.10))\n",
       "look-wild: every bud shown at once, ahead of the vine",
       expect="shows no later than the one before it", script=S)

mutate("Looks/Wild.lua",
       "\tself.tipAnim.move:SetOffset(span - 4, 0)\n",
       "\tself.tipAnim.move:SetOffset(0, 0)\n",
       "look-wild: the light at the vine's tip standing still",
       expect="does not run its length", script=S)

mutate("Looks/Wild.lua",
       "\tif not self.grown then\n\t\tself:Grown()\n\t\tself.vineFrame:SetAlpha(1)\n\tend\n",
       "\tif not self.grown then\n\t\tself:Grown()\n\tend\n",
       "look-wild: no vine after a restyle with somebody owed",
       expect="after a restyle with somebody owed the vine is not on the bough", script=S)

# --- the blossoms and the breath ---

mutate("Looks/Wild.lua",
       "\t\tself.blossomSheets[i] = flow:Sheet(t, BLOSSOM_COLS, BLOSSOM_ROWS, BLOSSOM_FRAMES, BLOSSOMS.fps[i], false)\n",
       "\t\tself.blossomSheets[i] = flow:Sheet(t, BLOSSOM_COLS, BLOSSOM_ROWS, BLOSSOM_FRAMES, BLOSSOMS.fps[1], false)\n",
       "look-wild: the three blossoms opening as one",
       expect="opens no slower than the one before it", script=S)

mutate("Looks/Wild.lua",
       "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n\t\t\tif gen ~= Wild.pulseGen or not Wild.active then return end\n",
       "\t\tC_Timer.After(BREATHS * BREATH * 20, function()\n\t\t\tif gen ~= Wild.pulseGen or not Wild.active then return end\n",
       "look-wild: the breath never held",
       expect="after three breaths, breath", script=S)

mutate("Looks/Wild.lua",
       "\t\t\tlocal k = self.owed and WATER.owed or 1\n",
       "\t\t\tlocal k = 1\n",
       "look-wild: the water no faster with somebody owed",
       expect="no faster than its", script=S)

mutate("Looks/Wild.lua",
       "\tself.core:SetAlpha(CORE.rest)\n\tself:Ungrow()\n",
       "\tself.core:SetAlpha(CORE.rest)\n",
       "look-wild: the vine left on the bough with nobody owed",
       expect="nobody owed, and the vine is still on the bough", script=S)

# --- the flourishes ---

mutate("Looks/Wild.lua",
       "\t\tself.pawAnim:Stop()\n\t\tself.pawAnim:Play()\n",
       "\t\tself.pawAnim:Stop()\n",
       "look-wild: a landing without the Mark of the Wild",
       expect="a landing lit no paw", script=S)

mutate("Looks/Wild.lua",
       "\tPlayAll(self.burstAnims)\n",
       "",
       "look-wild: a landing that throws no leaves",
       expect="a landing threw 0 leaves", script=S)

mutate("Looks/Wild.lua",
       "\t\tPlayAll(self.shed)\n\t\tPlayAll(self.petalAnims)\n",
       "\t\tPlayAll(self.petalAnims)\n",
       "look-wild: petals flying from blossoms that stay",
       expect="a landing did not shed every blossom", script=S)

mutate("Looks/Wild.lua",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n\tif kind ~= \"cast\" then return end\n",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n",
       "look-wild: leaves thrown for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Wild.lua",
       "\tlocal alive = on and not self.refused\n",
       "\tlocal alive = on\n",
       "look-wild: the water rippling on after a refusal",
       expect="after a refusal the water still ripples", script=S)

mutate("Looks/Wild.lua",
       "\t\t\t\tg:Stop()\n\t\t\t\tif self.sprigOn[i] then g:Play() end\n",
       "\t\t\t\tg:Stop()\n",
       "look-wild: a refusal that drops no husks",
       expect="a refusal dropped no husk", script=S)

mutate("Looks/Wild.lua",
       "\t\t\tt:SetVertexColor(SERE[1], SERE[2], SERE[3], 1)\n",
       "\t\t\tt:SetVertexColor(1, 1, 1, 1)\n",
       "look-wild: leaves greyed by a refusal, not browned",
       expect="a refusal did not brown", script=S)

mutate("Looks/Wild.lua",
       "\tself.leafy = { self.disc }\n\tfor _, t in ipairs(self.sprigs) do self.leafy[#self.leafy + 1] = t end\n\tself.baked = { self.antlers[1], self.antlers[2], self.lip, self.glyph }\n",
       "\tself.leafy = { self.disc, self.antlers[1], self.antlers[2] }\n\tfor _, t in ipairs(self.sprigs) do self.leafy[#self.leafy + 1] = t end\n\tself.baked = { self.lip, self.glyph }\n",
       "look-wild: antlers that wither",
       expect="a refusal greyed the antlers", script=S)

mutate("Looks/Wild.lua",
       "\tself:Water(SPENT[1], SPENT[2], SPENT[3])\n",
       "",
       "look-wild: the water in its colour after a refusal",
       expect="a refusal did not leave the water spent", script=S)

mutate("Looks/Wild.lua",
       "\tAlpha(g, 0.75, 0, 0.27, 3, nil, \"IN\")\n\tPark(g, region, 0)\n",
       "\tAlpha(g, 0.75, 0, 0.27, 3, nil, \"IN\")\n\tPark(g, region, 1)\n",
       "look-wild: the vine back as soon as it has withered",
       expect="a refusal left the vine on the bough", script=S)

# --- the list hung over the panel ---

mutate("Looks/Wild.lua",
       "\tif above then vineH = math.min(vineH, upper / VINE_STEM) end\n",
       "",
       "look-wild: the vine standing up into the list",
       expect="with the list above, the vine reaches", script=S)

mutate("Looks/Wild.lua",
       "\t\tif above then by = math.max(by, bs / 2) end\n",
       "",
       "look-wild: the blossoms standing up into the list",
       expect="with the list above, blossom", script=S)

mutate("Looks/Wild.lua",
       "\t\t{ x0 + span * 0.33, upper, false, span >= 60 and not above },\n",
       "\t\t{ x0 + span * 0.33, upper, false, span >= 60 },\n",
       "look-wild: a sprig standing up into the list",
       expect="a sprig stands up into it", script=S)

mutate("Looks/Wild.lua",
       "\t\tself.listX0 = math.max(self.listX0, circle * (1 + ANTLER_X) + 1)\n",
       "",
       "look-wild: the list hung over the antler",
       expect="under an antler that reaches", script=S)

# --- no light left ---

mutate("Looks/Wild.lua",
       "\tself.pawAnim = anim(Flash(self.paw, 0.80, 0.07, 0.43))\n",
       "\tself.pawAnim = anim(Flash(self.paw, 0.80, 0.07, 0.43, 0.5))\n",
       "look-wild: the paw left lit over the icon",
       expect="additive light left on", script=S)

mutate("Looks/Wild.lua",
       "local BURST_SECONDS = 0.58\n",
       "local BURST_SECONDS = 0.98\n",
       "look-wild: leaves that take a second to fly",
       expect="the landing's light", script=S)

# --- at rest ---

mutate("Looks/Wild.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-wild: the wood stirring through a fight",
       expect="in a fight, still running", script=S)

mutate("Looks/Wild.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-wild: the wood stirring on Calm",
       expect="on Calm, still running", script=S)

mutate("Looks/Wild.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-wild: the wood stirring under a prompt that is down",
       expect="with the prompt down, still running", script=S)

mutate("Looks/Wild.lua",
       "\t\tif turn.SetOrigin then turn:SetOrigin(hang and \"TOP\" or \"BOTTOM\", 0, 0) end\n",
       "\t\tif turn.SetOrigin then turn:SetOrigin(\"CENTER\", 0, 0) end\n",
       "look-wild: a sprig turning about its middle",
       expect="not its root", script=S)

mutate("Looks/Wild.lua",
       "\t-- Asked afresh: what stirs may stand elsewhere now.\n\tself.idleState = nil\n",
       "\t-- Asked afresh: what stirs may stand elsewhere now.\n",
       "look-wild: a restyle that leaves the wood as the last one had it",
       expect="a sprig that is not drawn still stirs", script=S)

mutate("Looks/Wild.lua",
       "local WATER = { tile = 19, du = { 0.034, -0.026 },",
       "local WATER = { tile = 19, du = { 0.034, 0.026 },",
       "look-wild: the water's two layers running as one",
       expect="the water's two layers run the same way", script=S)

mutate("Looks/Wild.lua",
       "\t\t{ x0 + span * 0.46, self.upper - 5 * lift, { 13, 5 * lift }, { 9, -4 * lift }, { -9, 4 * lift } },\n",
       "\t\t{ x0 + span * 0.46, self.upper - 5 * lift, { 13, -22 * lift }, { 9, -4 * lift }, { -9, 4 * lift } },\n",
       "look-wild: a firefly wandering over the words",
       expect="wanders over the words", script=S)

mutate("Looks/Wild.lua",
       "\tif name and not (entry.reason == \"owed\") then self:Greet() end\n",
       "",
       "look-wild: a new face on the panel and no glint on the moon",
       expect="the first face on the panel was not greeted", script=S)

# --- Calm and the fight ---

mutate("Looks/Wild.lua",
       "\t\tif full and self.vineOK then\n\t\t\tself:StopLights()\n",
       "\t\tif self.vineOK then\n\t\t\tself:StopLights()\n",
       "look-wild: the vine growing before the eye on Calm",
       expect="on Calm the vine was grown before the eye", script=S)

mutate("Looks/Wild.lua",
       "anim(Fade(self.vineFrame, 0, 1, 0.5)),\n",
       "anim(Fade(self.vineFrame, 0, 0, 0.5)),\n",
       "look-wild: nobody's vine on Calm",
       expect="on Calm the vine rests at", script=S)

mutate("Looks/Wild.lua",
       "\tif on then\n\t\tself:StopAttention()\n\t\tself:StopFlourishes()\n",
       "\tif on then\n\t\tself:StopFlourishes()\n",
       "look-wild: the wood left as it was until the fight's first repaint",
       expect="in a fight, still running", script=S)

mutate("Looks/Wild.lua",
       "\tEach(self.body, \"SetDesaturated\", fight or sere)\n",
       "\tEach(self.body, \"SetDesaturated\", sere)\n",
       "look-wild: the bough in its colours through a fight",
       expect="in a fight the bough keeps its colour", script=S)

# --- the layout ---

mutate("Looks/Wild.lua",
       "\tlocal textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP\n",
       "\tlocal textX = showIcon and (cx + TEXT_GAP) or BARE_GAP\n",
       "look-wild: the words under the wreath",
       expect="under a wreath that reaches", script=S)

mutate("Looks/Wild.lua",
       "\tself.chipInset = math.ceil(W - rootX) + 2\n",
       "\tself.chipInset = 18\n",
       "look-wild: the tags over the crozier",
       expect="the tags would lie over the crozier", script=S)

mutate("Looks/Wild.lua",
       "\tlocal over = END_OVER * su\n",
       "\tlocal over = 0\n",
       "look-wild: the crozier squashed into the bough's height",
       expect="does not stand proud of the bough", script=S)

mutate("Looks/Wild.lua",
       "\tlocal ph = math.min(H - 2 * plateIn, math.max(W * BOUGH_MAX, (fs + 2 + sub + 4) / FACE))\n",
       "\tlocal ph = H - 2 * plateIn\n",
       "look-wild: a crozier as wide as a tall button",
       expect="and its end takes", script=S)

# --- a name measured once ---

mutate("Looks/Wild.lua",
       "\t\tif secret or text ~= self.measuredText or size ~= self.measuredSize then\n",
       "\t\tif true then\n",
       "look-wild: a name at its smallest measured at every scan",
       expect="wild, a key bound", script=S)

# --- the generator ---

mutate("tools/make_wild_textures.py",
       "MOON_AT = 62.0 ",
       "MOON_AT = 52.0 ",
       "look-wild: the generator's crozier round another place than the look's moon",
       expect="MOON_AT is 62 in the Lua and 52.0 in the generator", script=S)

mutate("Looks/Wild.lua",
       "local VINE_FRAMES = 16\n",
       "local VINE_FRAMES = 12\n",
       "look-wild: the look playing fewer frames than the vine's sheet holds",
       expect="VINE_FRAMES is 12 in the Lua and 16 in the generator", script=S)

mutate("tools/make_wild_textures.py",
       "SEED = 7717\n",
       "SEED = 7718\n",
       "look-wild: the generator drawing other art than ships",
       expect="does not match the file that ships", script=S)
