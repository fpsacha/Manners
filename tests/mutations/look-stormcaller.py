# Mutations for the Stormcaller look (Looks/Stormcaller.lua, Manners.toc,
# tools/make_stormcaller_textures.py): registered and loaded, square or round
# as the switch says, the marker's carriers and each element's own colour,
# which element a reason wakes and what runs in the channel for it, the bolt
# from the sky and the sigils waking in turn, the three breaths and the arc,
# the chain lightning clear of the words, the refusal, the list hung over the
# panel, no additive light at rest, the elements alive only at rest on Full
# with the prompt up, Calm, a fight, the words past the totem and the tags
# left of the stone, the slab on a tall button, one alpha for a texture, and
# the Lua and the generator agreeing. Each is caught by the scenario in
# tests/scenarios/look-stormcaller.lua that names it.

S = "runscenarios.py"
LUA = "Looks/Stormcaller.lua"
IDLE = "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n"

# --- registered ---

mutate("Manners.toc",
       "Looks\\Frost.lua\nLooks\\Stormcaller.lua\n",
       "Looks\\Frost.lua\n",
       "look-stormcaller: the toc does not load the look",
       expect="look-stormcaller: it is registered and in the toc", script=S)

mutate(LUA,
       "\torder = 9.86,\n",
       "\torder = 11,\n",
       "look-stormcaller: after Glass in the picker",
       expect="stormcaller is not after Frost and before Glass", script=S)

mutate(LUA,
       "\tinkOnDark = true,\n",
       "",
       "look-stormcaller: the words not declared to stand on the slate",
       expect="the words are not declared to stand on the look's own ground", script=S)

# --- square or round, and Hide ---

mutate(LUA,
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(round and maskFile or WHITE) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "look-stormcaller: the cooldown swept round over a square icon",
       expect="Round the icon off off the cooldown's sweep is", script=S)

mutate(LUA,
       "\tself.rim:SetTexture(ART .. (round and \"RimRound\" or \"Rim\"))\n",
       "\tself.rim:SetTexture(ART .. \"Rim\")\n",
       "look-stormcaller: a square inlay round a round icon",
       expect="Round the icon off on the inlay is", script=S)

mutate(LUA,
       "\t\tself.fx:Shape(round, ART .. \"FxRing\", ART .. \"FxRingSq\", round and maskFile or nil)\n",
       "\t\tself.fx:Shape(true, ART .. \"FxRing\", ART .. \"FxRingSq\", round and maskFile or nil)\n",
       "look-stormcaller: round rings from a square icon",
       expect="Round the icon off off the rings are drawn in", script=S)

mutate(LUA,
       "\tself.rimFrame = frame(1)\n\tself.rim = tex(self.rimFrame, \"ARTWORK\", 1, \"Rim\")\n",
       "\tself.rimFrame = frame(1)\n\tself.rim = tex(art, \"ARTWORK\", -1, \"Rim\")\n",
       "look-stormcaller: the inlay under the icon's edge",
       expect="the inlay is on the art's own layer", script=S)

mutate(LUA,
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-stormcaller: the round mask left on the next look's icon",
       expect="look-stormcaller: every state paints on", script=S)

mutate(LUA,
       "\tself.active = nil\n\tself.flow:StopAll()\n",
       "\tself.active = nil\n",
       "look-stormcaller: the channel still running under the next look",
       expect="under another look, still running", script=S)

# --- the marker ---

mutate(LUA,
       "\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\treturn true, true\n",
       "look-stormcaller: the options told both marks are always on",
       expect="AccentCarriers says", script=S)

mutate(LUA,
       "\tif not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end\n",
       "",
       "look-stormcaller: the inlay coloured where the marker is the stripe",
       expect="the inlay is coloured", script=S)

mutate(LUA,
       "\t\tif stripe then sr, sg, sb = r, g, b end\n",
       "",
       "look-stormcaller: the sigils never in the reason's colour",
       expect="the fire sigil's light is not the channel's colour", script=S)

mutate(LUA,
       "\tif stripe then vr, vg, vb = r, g, b end\n",
       "",
       "look-stormcaller: the channel never in the reason's colour",
       expect="look-stormcaller: the eyes and the inlay, the sigils and the channel carry the reason", script=S)

# --- which element ---

mutate(LUA,
       "local ELEMENT = { target = AIR, owed = FIRE, group = WATER, self = WATER, nearby = EARTH }\n",
       "local ELEMENT = { target = AIR, owed = WATER, group = FIRE, self = WATER, nearby = EARTH }\n",
       "look-stormcaller: a favour owed wakes water",
       expect="look-stormcaller: each reason wakes its element", script=S)

mutate(LUA,
       "\tlocal all = reason == \"asked\"\n",
       "\tlocal all = false\n",
       "look-stormcaller: somebody who asked wakes one element",
       expect="somebody who asked wakes", script=S)

mutate(LUA,
       "\tif reason and reason ~= self.reason and not self.outcomeOn then\n\t\tself.reason = reason\n\t\tself:Tint()\n\tend\n",
       "",
       "look-stormcaller: the element stale under a marker of one colour",
       expect="a group member painted in the same colour wakes", script=S)

mutate(LUA,
       "local RUNS = { { 2, 2.0 }, { 1, 1.0 }, { 2, 1.0 }, { 1, 0.45 } }\n",
       "local RUNS = { { 1, 2.0 }, { 1, 1.0 }, { 2, 1.0 }, { 1, 0.45 } }\n",
       "look-stormcaller: lava for air",
       expect="target: the channel does not run water", script=S)

mutate(LUA,
       "\t\tlocal v0 = (SIGIL_TOP + SIGIL_STEP * (i - 1)) / 256\n",
       "\t\tlocal v0 = (SIGIL_TOP + SIGIL_STEP * (4 - i)) / 256\n",
       "look-stormcaller: the lit sigils upside down on the stone",
       expect="shows the wrong box of its file", script=S)

# --- a favour arriving ---

mutate(LUA,
       "\t\t\t\tself.strikeSheet:Play()\n",
       "",
       "look-stormcaller: no bolt from the sky",
       expect="a favour arriving did not play the bolt's frames", script=S)

mutate(LUA,
       "\t\tlocal wait = WAKE.first + WAKE.step * (i - 1)\n",
       "\t\tlocal wait = WAKE.first\n",
       "look-stormcaller: the four sigils flashing as one",
       expect="flashes no later than the one above it", script=S)

mutate(LUA,
       "\t\t\t\t\tif self.awake[i] then\n\t\t\t\t\t\tself.sigils[i]:SetAlpha(0)\n\t\t\t\t\t\tself.wakeIn[i]:Play()\n\t\t\t\t\tend\n",
       "\t\t\t\t\tself.wakeIn[i]:Play()\n",
       "look-stormcaller: every sigil left awake by an arrival",
       expect="faded in, asleep", script=S)

mutate(LUA,
       "\t\tif full then\n\t\t\tself:StopLights()\n\t\t\tStopAll(self.calm)\n",
       "\t\tif true then\n\t\t\tself:StopLights()\n\t\t\tStopAll(self.calm)\n",
       "look-stormcaller: the bolt on Calm",
       expect="on Calm the bolt came down", script=S)

# --- owed ---

mutate(LUA,
       "\t\t\t\tStorm:HoldPulse(true)\n",
       "",
       "look-stormcaller: the breath never ending",
       expect="after three breaths, breath", script=S)

mutate(LUA,
       "\tself.arcSheet:Stop()\n\tself.arc:SetAlpha(0)\n\tself:Lights(spent)\n",
       "\tself.arc:SetAlpha(0)\n\tself:Lights(spent)\n",
       "look-stormcaller: the arc's frames playing on after the breath",
       expect="after three breaths the arc still stands", script=S)

mutate(LUA,
       "\t\t\t\tlocal speed = (self.speed or 1) * (self.owed and FLOW.owed or 1)\n",
       "\t\t\t\tlocal speed = (self.speed or 1)\n",
       "look-stormcaller: the channel no faster for a favour owed",
       expect="no faster than its", script=S)

mutate(LUA,
       "\tself.arc = dark(tex(self.idleFrame, \"OVERLAY\", 1, \"Arc\"))\n",
       "\tself.arc = dark(tex(self.idleFrame, \"OVERLAY\", 1, \"Arc\", \"ADD\"))\n",
       "look-stormcaller: an additive arc standing for seconds",
       expect="the arc, which stands for seconds, is additive", script=S)

# --- a landing ---

mutate(LUA,
       "\t\t\t\tself.boltAnims[i]:Play()\n",
       "",
       "look-stormcaller: the chain's frames played dark",
       expect="was not lit", script=S)

mutate(LUA,
       "\t\t\t\t\th.t0 = h.t0 - 1 / BOLT_FPS\n",
       "",
       "look-stormcaller: one drawing along both edges",
       expect="the two chains are", script=S)

mutate(LUA,
       "\tlocal up = top - bh * 0.30\n",
       "\tlocal up = top + bh * 0.60\n",
       "look-stormcaller: the upper chain over the name",
       expect="the chain covers the words", script=S)

mutate(LUA,
       "\tif kind ~= \"cast\" then return end\n",
       "\tif kind ~= \"cast\" and kind ~= \"sent\" then return end\n",
       "look-stormcaller: lightning for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate(LUA,
       "local BOLT_FPS, STRIKE_FPS, ARC_FPS = 16, 18, 13\n",
       "local BOLT_FPS, STRIKE_FPS, ARC_FPS = 8, 18, 13\n",
       "look-stormcaller: an additive chain lit for a second",
       expect="the landing's light 1 stays lit", script=S)

mutate(LUA,
       "\t\tAlpha(g, peak, 0, 0.12, 3, nil, \"IN\")\n\t\tPark(g, region, 0)\n",
       "\t\tAlpha(g, peak, 0, 0.12, 3, nil, \"IN\")\n\t\tPark(g, region, peak)\n",
       "look-stormcaller: the lightning left standing",
       expect="additive light left on", script=S)

# --- a refusal ---

mutate(LUA,
       "\t\t\tif lit and shown then PlayAll(self.refusal) end\n",
       "",
       "look-stormcaller: the eyes out with no gutter",
       expect="a refusal did not gutter the eyes", script=S)

mutate(LUA,
       "\tself:Channel(self.liquid or 1, SPENT[1], SPENT[2], SPENT[3])\n\tStopAll(self.glowPulse)\n",
       "\tStopAll(self.glowPulse)\n",
       "look-stormcaller: the channel hot after a refusal",
       expect="a refusal did not cool the channel", script=S)

mutate(LUA,
       "\tlocal alive = on and not self.refused\n",
       "\tlocal alive = on\n",
       "look-stormcaller: the channel running after a refusal",
       expect="after a refusal the channel still runs", script=S)

mutate(LUA,
       "\t\tlocal on = self.awake[i] and not out\n",
       "\t\tlocal on = self.awake[i]\n",
       "look-stormcaller: the sigil awake after a refusal",
       expect="a refusal left", script=S)

# --- the list above ---

mutate(LUA,
       "\tself.bolts[1]:SetShown(self.boltOK and not above)\n",
       "\tself.bolts[1]:SetShown(self.boltOK)\n",
       "look-stormcaller: the upper chain drawn into the list",
       expect="with the list above, the upper chain is drawn into it", script=S)

mutate(LUA,
       "\t\t\tif i == 2 or not self.above then\n",
       "\t\t\tif true then\n",
       "look-stormcaller: the upper chain played into the list",
       expect="with the list above, a landing ran the upper chain", script=S)

mutate(LUA,
       "\t\tself.listX0 = math.max(self.listX0, cx + totem * 0.5 + 3)\n",
       "",
       "look-stormcaller: the list under the totem's wing",
       expect="with the list above, its tablet begins at", script=S)

# --- at rest ---

mutate(LUA, IDLE,
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-stormcaller: the elements stirring through a fight",
       expect="in a fight, still running", script=S)

mutate(LUA, IDLE,
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-stormcaller: the elements stirring on Calm",
       expect="on Calm, still running", script=S)

mutate(LUA, IDLE,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-stormcaller: the elements stirring under a prompt that is down",
       expect="with the prompt down, still running", script=S)

mutate(LUA,
       "\t\tif alive and self.steleOK and not self.awake[i] then\n",
       "\t\tif alive and self.steleOK then\n",
       "look-stormcaller: the awake sigil glimmering as if asleep",
       expect="the awake sigil glimmers as if asleep", script=S)

mutate(LUA,
       "\t\tself.shimAnims[i] = anim(Shimmer(t, wait, SHIMMER.round - 1.3 - wait, SHIMMER.peak))\n",
       "\t\tself.shimAnims[i] = anim(Shimmer(t, wait, SHIMMER.round - 1.3, SHIMMER.peak))\n",
       "look-stormcaller: the glimmers drifting apart",
       expect="glimmers on a round of its own", script=S)

mutate(LUA,
       "\t\tg.turn = Spin(g, degrees, seconds, 1, \"TOP\", \"IN_OUT\")\n",
       "\t\tg.turn = Spin(g, degrees, seconds, 1, \"CENTER\", \"IN_OUT\")\n",
       "look-stormcaller: a feather turning about its middle",
       expect="not its thong", script=S)

mutate(LUA,
       "\tself.skyward = { self.strike, self.arc, self.crown, self.bolts[1], self.bolts[2] }\n",
       "\tself.skyward = {}\n",
       "look-stormcaller: the lights that leave the panel not named",
       expect="`skyward` does not name the bolt from the sky", script=S)

# --- a fight ---

mutate(LUA,
       "\t\tt:SetDesaturated(fight)\n\t\tif fight then Colour(t, DULL[1], DULL[2], DULL[3]) else Colour(t, 1, 1, 1) end\n",
       "\t\tt:SetDesaturated(false)\n\t\tif fight then Colour(t, DULL[1], DULL[2], DULL[3]) else Colour(t, 1, 1, 1) end\n",
       "look-stormcaller: the totem in colour through a fight",
       expect="in a fight the slab, the totem, the standing stone or the feathers keep their colour", script=S)

mutate(LUA,
       "\t\tself.eyes:SetAlpha(out and 0 or (fight and EYES.combat or (held and EYES.held or EYES.rest)))\n",
       "\t\tself.eyes:SetAlpha(out and 0 or (held and EYES.held or EYES.rest))\n",
       "look-stormcaller: the eyes bright through a fight",
       expect="in a fight the eyes are not low", script=S)

# --- the layout ---

mutate(LUA,
       "\tlocal textX = showIcon and (reach + LAY.textGap) or ",
       "\tlocal textX = showIcon and (reach - 6) or ",
       "look-stormcaller: the words under the tusk",
       expect="under a tusk that reaches", script=S)

mutate(LUA,
       "\tlocal cx, cy = TOTEM_POST * totem, H / 2\n",
       "\tlocal cx, cy = TOTEM_POST * totem * 0.8, H / 2\n",
       "look-stormcaller: the totem's post past the panel's edge",
       expect="the totem's post passes the panel's left edge", script=S)

mutate(LUA,
       "\tself.chipInset = math.ceil(W - self.rootX) + 2\n",
       "\tself.chipInset = 8\n",
       "look-stormcaller: the tags over the standing stone",
       expect="the tags would lie over the standing stone", script=S)

mutate(LUA,
       "\tlocal top = cy - LAY.faceMid * ph\n",
       "\tlocal top = cy - ph / 2\n",
       "look-stormcaller: the words low on the slate",
       expect="the slate's middle is not the button's", script=S)

mutate(LUA,
       "\tlocal ph = math.min(H * LAY.slabH, math.max(W * LAY.slabMax, (fs + 2 + sub + 4) / LAY.face))\n",
       "\tlocal ph = H * LAY.slabH\n",
       "look-stormcaller: a slab as tall as a tall button",
       expect="tall on a panel", script=S)

# --- one alpha ---

mutate(LUA,
       "\t\t\tColour(pair[2], lr, lg, lb, FLOW.second)\n",
       "\t\t\tpair[2]:SetVertexColor(lr, lg, lb, 1)\n",
       "look-stormcaller: the channel's second layer at full strength in the game",
       expect="look-stormcaller: a colour leaves every light as faint as it was", script=S)

mutate(LUA,
       "\t\tColour(t, br, bg, bb)\n\tend\n\tfor _, t in ipairs(self.sparks) do Colour(t, br, bg, bb) end\n",
       "\t\tt:SetVertexColor(br, bg, bb, 1)\n\tend\n\tfor _, t in ipairs(self.sparks) do Colour(t, br, bg, bb) end\n",
       "look-stormcaller: the lightning standing lit in the game",
       expect="look-stormcaller: a colour leaves every light as faint as it was", script=S)

# --- the generator ---

mutate("tools/make_stormcaller_textures.py",
       "TOTEM_SCALE = 2.2 ",
       "TOTEM_SCALE = 2.0 ",
       "look-stormcaller: the generator's totem another size than the Lua's",
       expect="TOTEM_SCALE is", script=S)

mutate("tools/make_stormcaller_textures.py",
       "SEED = 4177\n",
       "SEED = 4178\n",
       "look-stormcaller: the generator drawing other art than ships",
       expect="does not match the file that ships", script=S)

mutate(LUA,
       "local RING_PEAK, RING_EDGE = 0.773, 0.914\n",
       "local RING_PEAK, RING_EDGE = 0.773, 0.80\n",
       "look-stormcaller: the rings' reach understated to the shared effects",
       expect="the ring files' peak and reach are not the generator's", script=S)

# --- the list ---

mutate(LUA,
       "(plateX + 2), self.rowX - reach)\n",
       "(plateX + 2), self.rowX + 30)\n",
       "look-stormcaller: the rows' pebbles off the tablet",
       expect="a row's pebble begins at", script=S)

mutate(LUA,
       "\tlocal reach = 9 + (sub + 1) / 2 + LAY.listRim\n",
       "\tlocal reach = 17\n",
       "look-stormcaller: the rows' pebbles on the tablet's rim of stone",
       expect="a row's pebble begins at", script=S)

mutate(LUA,
       "\t\ty0 = low - 4\n\t\ty1 = low + depth\n",
       "\t\ty0 = self.H + 6\n\t\ty1 = low + depth\n",
       "look-stormcaller: the tablet adrift under the slab",
       expect="the tablet does not hang from the slab's lower edge", script=S)

# --- the review's fixes: the channel's figure, Calm in the middle of a breath ---

mutate(LUA,
       "\tflowTile = 8,\n",
       "\tflowTile = 4,\n",
       "look-stormcaller: the channel's tile laid at half its length",
       expect="a tile of the channel is not eight times as long as it is tall", script=S)

mutate(LUA,
       "\t\t\t\tself.runScroll[i][k]:Window((x1 - x0) / tile * FLOW.long, -1)\n",
       "\t\t\t\tself.runScroll[i][k]:Window((x1 - x0) / tile, -1)\n",
       "look-stormcaller: the channel's second layer as long as its first",
       expect="the channel's second layer is the first one's drawing again", script=S)

mutate(LUA,
       "\t\t\t\tself.runScroll[i][k]:Window((x1 - x0) / tile * FLOW.long, -1)\n",
       "\t\t\t\tself.runScroll[i][k]:Window((x1 - x0) / tile * FLOW.long, 1)\n",
       "look-stormcaller: the channel's second layer the same way up as its first",
       expect="the channel's second layer is not laid upside down", script=S)

mutate(LUA,
       "local FLOW = { du = { 0.06, 0.022 },",
       "local FLOW = { du = { 0.06, 0.036 },",
       "look-stormcaller: the channel's two layers at one pace on the screen",
       expect="on the screen the channel's two layers drift as one", script=S)

mutate("tools/make_stormcaller_textures.py",
       "FLOW_W, FLOW_H = 256, 32\n",
       "FLOW_W, FLOW_H = 128, 32\n",
       "look-stormcaller: the generator drawing the channel's short tile",
       expect="Stormcaller_Lava.tga does not match the file that ships", script=S)

mutate("tools/make_stormcaller_textures.py",
       "sstep(1.0, 16.0, x) * sstep(fw, fw - 3.0, x)\n",
       "sstep(0.0, 3.0, x) * sstep(fw, fw - 3.0, x)\n",
       "look-stormcaller: the chain's start cut off over the totem",
       expect="Stormcaller_Bolt.tga does not match the file that ships", script=S)

mutate(LUA,
       "\t\t\tself.arcSheet:Stop()\n\t\t\tPlayAll(self.calm)\n",
       "\t\t\tPlayAll(self.calm)\n",
       "look-stormcaller: the arc's frames playing on under Calm",
       expect="turned to Calm in the middle of a breath, the arc's frames play on", script=S)

mutate("tools/make_stormcaller_textures.py",
       "    return (0.45 * mask + 0.55 * blur(mask, 5.0 * SS)).astype(np.float32)\n",
       "    return mask\n",
       "look-stormcaller: a breaking bolt's glow cut into holes",
       expect="Stormcaller_Bolt.tga does not match the file that ships", script=S)
