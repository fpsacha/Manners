# Mutations for the Frost look (Looks/Frost.lua, Looks/Looks.lua, Manners.toc,
# tools/make_frost_textures.py): registered and loaded, round whatever the
# switch says, the marker's carriers and ice's silver, the mist cut to its
# ring, the frost spread from both ends with a light at each front, the hoar,
# the seeds, the snowflakes each at its own pace, the three breaths, the Ice
# Block, its fractures, the nova, the shards and the burst snowflakes, the
# refusal's cracks, fallen icicles and dull ice and the mending after, the
# rime and the list under a list hung over the panel and the icicles out of
# one hung under it, no additive light at rest, the ice alive only at rest on
# Full with the prompt up, Calm, a fight, the words past the crystal and the
# tags left of the shards, the slab on a tall button, the words' contrast and
# the reason line's shadow, a name measured once, and the Lua and the
# generator agreeing. Each is caught by the scenario in
# tests/scenarios/look-frost.lua that names it (one by perf-budget.lua).

S = "runscenarios.py"

# --- registered ---

mutate("Looks/Looks.lua",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true, frost = true }\n",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true }\n",
       "look-frost: the round switch live on the crystal",
       expect="frost is not in roundAlways", script=S)

mutate("Manners.toc",
       "Looks\\Wild.lua\nLooks\\Frost.lua\n",
       "Looks\\Wild.lua\n",
       "look-frost: the toc does not load the look",
       expect="look-frost: it is registered, in the toc, and translated", script=S)

mutate("Looks/Frost.lua",
       "\torder = 9.8,\n",
       "\torder = 11,\n",
       "look-frost: after Glass in the picker",
       expect="frost is not after Wild and before Glass", script=S)

# --- round, and Hide ---

mutate("Looks/Frost.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-frost: the cooldown swept square over the crystal",
       expect="the cooldown's sweep is not cut round", script=S)

mutate("Looks/Frost.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-frost: the round mask left on the next look's icon",
       expect="look-frost: every state paints on", script=S)

mutate("Looks/Frost.lua",
       "\tself.active = nil\n\tself.flow:StopAll()\n",
       "\tself.active = nil\n",
       "look-frost: the mist still drifting under the next look",
       expect="under another look, still running", script=S)

mutate("Looks/Frost.lua",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.mistMask:Hide()\n",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "look-frost: the mist's mask left shown under the next look",
       expect="is still shown under another look", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.glints[1], self.glints[2] }) do\n\t\tt:SetShown(showIcon)\n",
       "\t\tself.glints[1], self.glints[2] }) do\n\t\tt:SetShown(true)\n",
       "look-frost: a crystal round an icon that is off",
       expect="with the icon off the crystal", script=S)

# --- the marker ---

mutate("Looks/Frost.lua",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "look-frost: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate("Looks/Frost.lua",
       "\tif not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end\n",
       "",
       "look-frost: the mist coloured whatever the marker",
       expect="the mist is coloured", script=S)

mutate("Looks/Frost.lua",
       "\tself.rune:SetVertexColor(vr, vg, vb, 1)\n",
       "\tself.rune:SetVertexColor(r, g, b, 1)\n",
       "look-frost: the rune coloured whatever the marker",
       expect="the rune is coloured", script=S)

mutate("Looks/Frost.lua",
       "\tself.vein:SetVertexColor(vr, vg, vb, VEIN_ALPHA)\n",
       "\tself.vein:SetVertexColor(cr, cg, cb, VEIN_ALPHA)\n",
       "look-frost: the vein coloured by the icon's marker",
       expect="the vein is", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.mist[i]:AddMaskTexture(self.mistMask)\n",
       "",
       "look-frost: the mist a square under the crystal",
       expect="is not cut to its ring", script=S)

# --- the frost spreading ---

mutate("Looks/Frost.lua",
       "\t\t\tfor _, h in ipairs(self.rimeSheets) do h:Play() end\n\t\t\tfor _, h in ipairs(self.flakeSheets) do h:Play() end\n",
       "\t\t\tfor _, h in ipairs(self.flakeSheets) do h:Play() end\n",
       "look-frost: rime that comes whole",
       expect="a favour arriving did not play the rime's frames", script=S)

mutate("Looks/Frost.lua",
       "\t\t\tPlayAll(self.arrive)\n\t\t\t-- Both halves at once, each from its own end.\n",
       "\t\t\t-- Both halves at once, each from its own end.\n",
       "look-frost: a favour arriving brings no frost",
       expect="a favour arriving did not bring the frost", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.rimeSheets[i] = flow:Sheet(t, RIME_COLS, RIME_ROWS, RIME_FRAMES, RIME_FPS, false)\n",
       "\t\tself.rimeSheets[i] = flow:Sheet(t, RIME_COLS, RIME_ROWS, RIME_FRAMES, RIME_FPS, true)\n",
       "look-frost: rime that creeps over and over",
       expect="the rime's frames loop", script=S)

mutate("Looks/Frost.lua",
       "\tBox(self.rimes[2], art, x0 + span / 2, top, x0 + span, top + rimeH)\n",
       "\tBox(self.rimes[2], art, x0 + span / 2 + 6, top, x0 + span, top + rimeH)\n",
       "look-frost: a gap where the rime's two halves should meet",
       expect="the rime's two halves do not meet", script=S)

mutate("Looks/Frost.lua",
       "\tself.hoar = tex(self.rimeFrame, \"ARTWORK\", -1, \"Hoar\", nil, \"REPEAT\", \"CLAMP\")\n",
       "\tself.hoar = tex(art, \"ARTWORK\", -1, \"Hoar\", nil, \"REPEAT\", \"CLAMP\")\n",
       "look-frost: hoar on the rim with nobody owed",
       expect="the hoar does not come and go with the rime", script=S)

mutate("Looks/Frost.lua",
       "\thoar:SetTexCoord(1 - (n % 1), 1 + math.floor(n), 0, 1)\n",
       "\thoar:SetTexCoord(0, 1, 0, 1)\n",
       "look-frost: the hoar stretched over a rim it was not drawn for",
       expect="the hoar is not tiled as the rim it lies on", script=S)

mutate("Looks/Frost.lua",
       "\tself.tipAnims[2].move:SetOffset(-(span / 2 - 2), 0)\n",
       "\tself.tipAnims[2].move:SetOffset(span / 2 - 2, 0)\n",
       "look-frost: the far front's light running off the slab",
       expect="the light at front 2 does not run its half", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.seedIn[i] = anim(Fade(t, 0, 1, 0.12, 0.05 + reached * 0.8))\n",
       "\t\tself.seedIn[i] = anim(Fade(t, 0, 1, 0.12, 0.05))\n",
       "look-frost: every seed shown at once, ahead of the rime",
       expect="the middle snowflake's seed shows no later", script=S)

mutate("Looks/Frost.lua",
       "\tif not self.grown then\n\t\tself:Grown()\n\t\tself.rimeFrame:SetAlpha(1)\n\tend\n",
       "\tif not self.grown then\n\t\tself:Grown()\n\tend\n",
       "look-frost: no rime after a restyle with somebody owed",
       expect="after a restyle with somebody owed the rime is not on the slab", script=S)

# --- the snowflakes and the breath ---

mutate("Looks/Frost.lua",
       "\t\tself.flakeSheets[i] = flow:Sheet(t, FLAKE_COLS, FLAKE_ROWS, FLAKE_FRAMES, FLAKES.fps[i], false)\n",
       "\t\tself.flakeSheets[i] = flow:Sheet(t, FLAKE_COLS, FLAKE_ROWS, FLAKE_FRAMES, FLAKES.fps[1], false)\n",
       "look-frost: the three snowflakes growing as one",
       expect="crystallises no slower than the one before it", script=S)

mutate("Looks/Frost.lua",
       "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n\t\t\tif gen ~= Frost.pulseGen or not Frost.active then return end\n",
       "\t\tC_Timer.After(BREATHS * BREATH * 20, function()\n\t\t\tif gen ~= Frost.pulseGen or not Frost.active then return end\n",
       "look-frost: the breath never held",
       expect="after three breaths, breath", script=S)

mutate("Looks/Frost.lua",
       "\t\t\tlocal k = self.owed and MIST.owed or 1\n",
       "\t\t\tlocal k = 1\n",
       "look-frost: the mist no faster with somebody owed",
       expect="no faster than its", script=S)

mutate("Looks/Frost.lua",
       "\tself.core:SetAlpha(CORE.rest)\n\tself:Ungrow()\n",
       "\tself.core:SetAlpha(CORE.rest)\n",
       "look-frost: the rime left on the slab with nobody owed",
       expect="nobody owed, and the rime is still on the slab", script=S)

# --- the landing ---

mutate("Looks/Frost.lua",
       "\t\tself.blockAnim:Stop()\n\t\tself.blockAnim:Play()\n",
       "\t\tself.blockAnim:Stop()\n",
       "look-frost: a landing without the Ice Block",
       expect="a landing shut no ice block", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.novaAnim:Stop()\n\t\tself.novaAnim:Play()\n",
       "\t\tself.novaAnim:Stop()\n",
       "look-frost: a landing without the nova",
       expect="a landing flashed no nova", script=S)

mutate("Looks/Frost.lua",
       "\tPlayAll(self.shardAnims)\n",
       "",
       "look-frost: an ice block that shatters into nothing",
       expect="a landing threw 0 shards", script=S)

mutate("Looks/Frost.lua",
       "\t\tPlayAll(self.shed)\n\t\tPlayAll(self.sparkAnims)\n",
       "\t\tPlayAll(self.sparkAnims)\n",
       "look-frost: splinters flying from snowflakes that stay",
       expect="a landing did not burst every snowflake", script=S)

mutate("Looks/Frost.lua",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n\tif kind ~= \"cast\" then return end\n",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n",
       "look-frost: an ice block for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Frost.lua",
       "\tAt(self.block, art, cx, cy, iconSize * 1.06)\n",
       "\tAt(self.block, art, cx, cy, iconSize * 0.70)\n",
       "look-frost: an ice block that shuts over half the icon",
       expect="the ice block does not shut over the icon", script=S)

mutate("Looks/Frost.lua",
       "\tself.block = tex(self.lightFrame, \"OVERLAY\", 1, \"Block\")\n",
       "\tself.block = tex(self.lightFrame, \"OVERLAY\", 1, \"Block\", \"ADD\")\n",
       "look-frost: an ice block made of light",
       expect="the ice block is light, not ice", script=S)

mutate("Looks/Frost.lua",
       "local SHATTER_AT, SHARD_SECONDS = 0.14, 0.44\n",
       "local SHATTER_AT, SHARD_SECONDS = 0, 0.44\n",
       "look-frost: shards flying before the block has shut",
       expect="before the block has shut and broken", script=S)

mutate("Looks/Frost.lua",
       "local BLOCK = { shut = 0.05, hold = 0.09, gone = 0.12, alpha = 0.92 }\n",
       "local BLOCK = { shut = 0.05, hold = 0.60, gone = 0.12, alpha = 0.92 }\n",
       "look-frost: an ice block that hides the icon for most of a second",
       expect="the ice block hides the icon for", script=S)

mutate("Looks/Frost.lua",
       "local SHARDS = { { 96, 0.74, 260 },",
       "local SHARDS = { { 10, 0.74, 260 },",
       "look-frost: a shard thrown at the words",
       expect="shard 1 flies across the words", script=S)

# --- the refusal ---

mutate("Looks/Frost.lua",
       "\t\t\t\tself.rimeFrame:SetAlpha(1)\n\t\t\t\tself.meltAnim:Play()\n",
       "\t\t\t\tself.rimeFrame:SetAlpha(1)\n",
       "look-frost: a refusal that melts nothing",
       expect="a refusal did not melt the rime", script=S)

mutate("Looks/Frost.lua",
       "\t\t\t\tg:Stop()\n\t\t\t\tif self.crackOn[i] then g:Play() end\n",
       "\t\t\t\tg:Stop()\n",
       "look-frost: a refusal that runs no crack",
       expect="a refusal ran no crack", script=S)

mutate("Looks/Frost.lua",
       "\t\t\t\tg:Stop()\n\t\t\t\tif self.icicleUp[i] then g:Play() end\n",
       "\t\t\t\tg:Stop()\n",
       "look-frost: a refusal that drops no icicle",
       expect="a refusal dropped 0 icicles", script=S)

mutate("Looks/Frost.lua",
       "\tlocal gone = self.refused or self:ListBelow()\n",
       "\tlocal gone = self:ListBelow()\n",
       "look-frost: icicles that fall and hang still",
       expect="after a refusal icicle", script=S)

mutate("Looks/Frost.lua",
       "\tself:Mist(SPENT[1], SPENT[2], SPENT[3])\n",
       "",
       "look-frost: the mist in its colour after a refusal",
       expect="a refusal did not leave the mist spent", script=S)

mutate("Looks/Frost.lua",
       "\t\t\tt:SetVertexColor(DEAD[1], DEAD[2], DEAD[3], 1)\n",
       "\t\t\tt:SetVertexColor(1, 1, 1, 1)\n",
       "look-frost: ice greyed by a refusal and no duller",
       expect="a refusal did not dull the crystal", script=S)

mutate("Looks/Frost.lua",
       "\tEach(self.body, \"SetDesaturated\", fight or dead)\n",
       "\tEach(self.body, \"SetDesaturated\", fight)\n",
       "look-frost: a slab in its blue after a refusal",
       expect="a refusal did not dull the slab", script=S)

mutate("Looks/Frost.lua",
       "\tlocal alive = on and not self.refused\n",
       "\tlocal alive = on\n",
       "look-frost: the mist drifting on after a refusal",
       expect="after a refusal the mist still drifts", script=S)

mutate("Looks/Frost.lua",
       "\tAlpha(g, 0.75, 0, 0.27, 3, nil, \"IN\")\n\tPark(g, region, 0)\n",
       "\tAlpha(g, 0.75, 0, 0.27, 3, nil, \"IN\")\n\tPark(g, region, 1)\n",
       "look-frost: the rime back as soon as it has melted",
       expect="a refusal left the rime on the slab", script=S)

mutate("Looks/Frost.lua",
       "\tfor i, t in ipairs(self.cracks) do self.crackIn[i] = anim(Fade(t, 0, CRACK_HELD, 0.07, 0.05 * (i - 1))) end\n",
       "\tfor i, t in ipairs(self.cracks) do self.crackIn[i] = anim(Flash(t, CRACK_HELD, 0.07, 0.20, 0, 0.05 * (i - 1))) end\n",
       "look-frost: cracks that close as soon as they have run",
       expect="half a second after a refusal crack", script=S)

mutate("Looks/Frost.lua",
       "\tStopAll(self.crackIn)\n\tfor _, t in ipairs(self.cracks) do t:SetAlpha(0) end\n",
       "\tStopAll(self.crackIn)\n",
       "look-frost: a slab cracked for good",
       expect="after the refusal crack", script=S)

mutate("Looks/Frost.lua",
       "\tif was then self:Mend() end\n",
       "",
       "look-frost: a slab never mended after a refusal",
       expect="after the refusal the ice stays dull", script=S)

mutate("Looks/Frost.lua",
       "\tBox(self.cracks[2], art, x0 + span - cw, plateIn, x0 + span, H - plateIn)\n",
       "\tBox(self.cracks[2], art, x0 + span - cw + 40, plateIn, x0 + span + 40, H - plateIn)\n",
       "look-frost: a crack run on under the shards",
       expect="the cracks leave the slab's face", script=S)

# --- the lists ---

mutate("Looks/Frost.lua",
       "\tif above then rimeH = math.min(rimeH, upper / RIME_ROOT) end\n",
       "",
       "look-frost: the rime standing up into the list",
       expect="with the list above, the rime reaches", script=S)

mutate("Looks/Frost.lua",
       "\t\tif above then by = math.max(by, bs / 2) end\n",
       "",
       "look-frost: the snowflakes standing up into the list",
       expect="with the list above, snowflake", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.listX0 = math.max(self.listX0, circle + 1)\n",
       "",
       "look-frost: the list hung over the crystal",
       expect="under a crystal that reaches", script=S)

mutate("Looks/Frost.lua",
       "\treturn (self.listShown and not self.listAt) and true or false\n",
       "\treturn false\n",
       "look-frost: icicles hanging into the list under the slab",
       expect="hangs into the list under the slab", script=S)

mutate("Looks/Frost.lua",
       "\t\t\t-- The icicles hang again where the list hung.\n\t\t\tself:Hang()\n",
       "\t\t\t-- The icicles hang again where the list hung.\n",
       "look-frost: no icicles once the list has gone",
       expect="with the list gone the icicles do not hang and drip again", script=S)

# --- no light left ---

mutate("Looks/Frost.lua",
       "\tself.crackleAnim = anim(Flash(self.crackle, 0.90, 0.05, 0.30, 0, BLOCK.shut + BLOCK.hold - 0.04))\n",
       "\tself.crackleAnim = anim(Flash(self.crackle, 0.90, 0.05, 0.30, 0.5, BLOCK.shut + BLOCK.hold - 0.04))\n",
       "look-frost: the block's fractures left lit over the icon",
       expect="additive light left on", script=S)

mutate("Looks/Frost.lua",
       "local SHATTER_AT, SHARD_SECONDS = 0.14, 0.44\n",
       "local SHATTER_AT, SHARD_SECONDS = 0.14, 0.94\n",
       "look-frost: shards that take a second to fly",
       expect="the landing's light", script=S)

# --- at rest ---

mutate("Looks/Frost.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-frost: the snow falling through a fight",
       expect="in a fight, still running", script=S)

mutate("Looks/Frost.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-frost: the snow falling on Calm",
       expect="on Calm, still running", script=S)

mutate("Looks/Frost.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-frost: the snow falling under a prompt that is down",
       expect="with the prompt down, still running", script=S)

mutate("Looks/Frost.lua",
       "\tif alive and self.icicleUp[DRIP] then\n",
       "\tif alive then\n",
       "look-frost: a drop from an icicle that is not there",
       expect="an icicle that is not drawn still drips", script=S)

mutate("Looks/Frost.lua",
       "\t-- Asked afresh: what falls may fall elsewhere now.\n\tself.idleState = nil\n",
       "\t-- Asked afresh: what falls may fall elsewhere now.\n",
       "look-frost: a restyle that leaves the ice as the last one had it",
       expect="after the panel is widened, not running", script=S)

mutate("Looks/Frost.lua",
       "local MIST = { tile = 22, du = { 0.040, -0.028 },",
       "local MIST = { tile = 22, du = { 0.040, 0.028 },",
       "look-frost: the mist's two layers running as one",
       expect="the mist's two layers run the same way", script=S)

mutate("Looks/Frost.lua",
       "\t\t{ x0 + span * 0.30, -9 * lift, 5, self.upper + 9 * lift - 2 },\n",
       "\t\t{ x0 + span * 0.30, -9 * lift, 5, H * 0.8 },\n",
       "look-frost: snow falling across the words",
       expect="falls across the words", script=S)

mutate("Looks/Frost.lua",
       "\tAt(self.drop, art, drip[1] - drip[3] * 0.0625, drip[2] + drip[3] * 0.96, math.max(4, drip[3] * 0.26))\n",
       "\tAt(self.drop, art, drip[1] - drip[3] * 0.0625, drip[2] + drip[3] * 0.30, math.max(4, drip[3] * 0.26))\n",
       "look-frost: a drop from the middle of its icicle",
       expect="from the point of its icicle", script=S)

mutate("Looks/Frost.lua",
       "\tif name and not (entry.reason == \"owed\") then self:Greet() end\n",
       "",
       "look-frost: a new face on the panel and no glint on the rune",
       expect="the first face on the panel was not greeted", script=S)

mutate("Looks/Frost.lua",
       "\t\tself.idle[#self.idle + 1] = self.snowAnims[i]\n",
       "",
       "look-frost: the snow looping unnamed",
       expect="loop(s) kept going with nobody owed", script=S)

# --- Calm and the fight ---

mutate("Looks/Frost.lua",
       "\t\tif full and self.rimeOK then\n\t\t\tself:StopLights()\n",
       "\t\tif self.rimeOK then\n\t\t\tself:StopLights()\n",
       "look-frost: the frost spreading before the eye on Calm",
       expect="on Calm the frost spread before the eye", script=S)

mutate("Looks/Frost.lua",
       "anim(Fade(self.rimeFrame, 0, 1, 0.5)),\n",
       "anim(Fade(self.rimeFrame, 0, 0, 0.5)),\n",
       "look-frost: nobody's rime on Calm",
       expect="on Calm the rime rests at", script=S)

mutate("Looks/Frost.lua",
       "\t\tif not self.crackIn[i]:IsPlaying() then t:SetAlpha(CRACK_HELD) end\n",
       "",
       "look-frost: a refused slab left whole on Calm",
       expect="on Calm a refused slab is not cracked", script=S)

mutate("Looks/Frost.lua",
       "\tif on then\n\t\tself:StopAttention()\n\t\tself:StopFlourishes()\n",
       "\tif on then\n\t\tself:StopFlourishes()\n",
       "look-frost: the ice left as it was until the fight's first repaint",
       expect="in a fight the rime stays on the slab", script=S)

mutate("Looks/Frost.lua",
       "\tEach(self.body, \"SetDesaturated\", fight or dead)\n",
       "\tEach(self.body, \"SetDesaturated\", dead)\n",
       "look-frost: the slab in its colours through a fight",
       expect="in a fight the slab keeps its colour", script=S)

# --- the layout ---

mutate("Looks/Frost.lua",
       "\tlocal textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP\n",
       "\tlocal textX = showIcon and (cx + TEXT_GAP) or BARE_GAP\n",
       "look-frost: the words under the crystal",
       expect="under a crystal that reaches", script=S)

mutate("Looks/Frost.lua",
       "\tself.chipInset = math.ceil(W - rootX) + 2\n",
       "\tself.chipInset = 18\n",
       "look-frost: the tags over the shards",
       expect="the tags would lie over the shards", script=S)

mutate("Looks/Frost.lua",
       "\tlocal over = END_OVER * su\n",
       "\tlocal over = 0\n",
       "look-frost: the shards squashed into the slab's height",
       expect="does not stand proud of the slab", script=S)

mutate("Looks/Frost.lua",
       "\tlocal ph = math.min(H - 2 * plateIn, math.max(W * SLAB_MAX, (fs + 2 + sub + 4) / FACE))\n",
       "\tlocal ph = H - 2 * plateIn\n",
       "look-frost: shards as wide as a tall button",
       expect="and its end takes", script=S)

# --- the words ---

mutate("Looks/Frost.lua",
       "\tkit.sub:SetShadowColor(0, 0.01, 0.04, 1)\n\tkit.sub:SetShadowOffset(1, -1)\n",
       "",
       "look-frost: the reason line with whatever shadow the panel colour left it",
       expect="the reason line on a light panel colour has no full dark shadow", script=S)

mutate("Looks/Frost.lua",
       "\tsr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)\n",
       "",
       "look-frost: the reason line in the reason's colour however dark",
       expect="the reason line reads at", script=S)

mutate("Looks/Frost.lua",
       "\tlocal vr, vg, vb = kit.Legible(o[1], o[2], o[3], SUB_CONTRAST)\n",
       "\tlocal vr, vg, vb = o[1] * 0.6, o[2] * 0.6, o[3] * 0.6\n",
       "look-frost: a verdict dimmer than the deep ice lets it read",
       expect="the verdict of a", script=S)

mutate("Looks/Frost.lua",
       "\tink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)\n",
       "\tink.lo, ink.hi = Luminance(TABLE_LO), Luminance(0.9)\n",
       "look-frost: the words judged against a ground that is not theirs",
       expect="the reason line reads at", script=S)

# --- a name measured once ---

mutate("Looks/Frost.lua",
       "\t\tif secret or text ~= self.measuredText or size ~= self.measuredSize then\n",
       "\t\tif true then\n",
       "look-frost: a name at its smallest measured at every scan",
       expect="frost, a key bound", script=S)

# --- the generator ---

mutate("tools/make_frost_textures.py",
       "RUNE_AT = 52.0 ",
       "RUNE_AT = 42.0 ",
       "look-frost: the generator's socket in another place than the look's rune",
       expect="RUNE_AT is 52 in the Lua and 42.0 in the generator", script=S)

mutate("Looks/Frost.lua",
       "local RIME_FRAMES = 16\n",
       "local RIME_FRAMES = 12\n",
       "look-frost: the look playing fewer frames than the rime's sheet holds",
       expect="RIME_FRAMES is 12 in the Lua and 16 in the generator", script=S)

mutate("tools/make_frost_textures.py",
       "SEED = 4127\n",
       "SEED = 4128\n",
       "look-frost: the generator drawing other art than ships",
       expect="does not match the file that ships", script=S)
