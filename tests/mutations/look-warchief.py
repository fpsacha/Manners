# Mutations for the Warchief look (Looks/Warchief.lua,
# tools/make_warchief_textures.py): in the toc, the chamfered square whatever
# the switch says, the marker's carriers, the crest struck and the sparks
# from it, the three breaths with their coals and embers, the soot under the
# words, the drum's two beats, the refusal, the list clear of the spikes and
# the banner, no additive light at rest, the banner stirring only at rest,
# Calm, a fight, the words past the tusks, and the Lua and the generator
# agreeing. Each is caught by the scenario in tests/scenarios/look-warchief.lua
# that names it.

S = "runscenarios.py"
LUA = "Looks/Warchief.lua"
GEN = "tools/make_warchief_textures.py"

# --- registered ---

mutate("Manners.toc",
       "Looks\\Warchief.lua\n",
       "",
       "look-warchief: the toc does not load the look",
       expect="look-warchief: it is registered and in the toc", script=S)

# --- the chamfered square ---

mutate(LUA,
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-warchief: the cooldown swept square over the cut corners",
       expect="the cooldown's sweep is not cut to the icon", script=S)

mutate(LUA,
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-warchief: the chamfered mask left on the next look's icon",
       expect="the chamfered mask was left on the icon", script=S)

# --- the marker ---

mutate(LUA,
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "look-warchief: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate(LUA,
       "\tif not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "look-warchief: the brand coloured with the marker on the stripe",
       expect="the brand is coloured", script=S)

mutate(LUA,
       "\tColour(self.paint, vr, vg, vb, PAINT_ALPHA)\n",
       "\tColour(self.paint, cr, cg, cb, PAINT_ALPHA)\n",
       "look-warchief: the paint follows the brand, not the stripe",
       expect="the paint is", script=S)

mutate(LUA,
       "\tlocal eb = EMBER[3] + (cb - EMBER[3]) * EMBER_REASON\n",
       "\tlocal eb = 1\n",
       "look-warchief: the crest glows cold",
       expect="the crest's glow is not the ember's colour", script=S)

# --- a favour arriving ---

mutate(LUA,
       "\t\t\tself:StopLights()\n\t\t\tPlayAll(self.arrive)\n",
       "\t\t\tself:StopLights()\n",
       "look-warchief: a favour arrives and nothing strikes the crest",
       expect="a favour arriving did not strike the crest", script=S)

mutate(LUA,
       "\t\t\tself:Sparks(self.crestX, self.H / 2, self.crestSide * 1.9)\n",
       "\t\t\tself:Sparks(self.cx, self.H / 2, self.crestSide * 1.9)\n",
       "look-warchief: the arrival's sparks fly from the icon",
       expect="the arrival's sparks are not about the crest's middle", script=S)

mutate(LUA,
       "\t-- The crest may light from here on: the soot comes up under the words.\n\tself:SootUp(true)\n",
       "\t-- The crest may light from here on: the soot comes up under the words.\n",
       "look-warchief: the crest lights with no soot under the words",
       expect="did not bring the soot up under the words", script=S)

# --- the breath ---

mutate(LUA,
       "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n",
       "\t\tC_Timer.After(BREATHS * BREATH * 20, function()\n",
       "look-warchief: the crest breathes for a minute",
       expect="after three breaths, breath", script=S)

mutate(LUA,
       "function Warchief:HoldPulse(spent)\n\tStopAll(self.pulse)\n\tStopAll(self.rise)\n",
       "function Warchief:HoldPulse(spent)\n\tStopAll(self.pulse)\n",
       "look-warchief: the embers rise for as long as somebody waits",
       expect="after three breaths, ember", script=S)

mutate(LUA,
       "\t\tif self.crestOK then PlayAll(self.rise) end\n",
       "",
       "look-warchief: no embers over the breathing crest",
       expect="does not rise", script=S)

mutate(LUA,
       "local COALS = { span = { 1.5, 2.1 }, du = { 0.012, -0.021 }, dv = { 0.050, 0.031 } }\n",
       "local COALS = { span = { 1.5, 2.1 }, du = { 0.012, 0.021 }, dv = { 0.050, 0.031 } }\n",
       "look-warchief: the two coal fields crawl the same way",
       expect="the two coal fields do not cross one another", script=S)

mutate(LUA,
       "\tself:Stand(2)\n\tself.calmLit, self.lit = nil, nil\n",
       "\tself:Stand(2)\n\tself.calmLit = nil\n",
       "look-warchief: the coals crawl on in a crest gone dark",
       expect="with nobody owed, coal field", script=S)

mutate(LUA,
       "\tif self.sootOn then self:SootUp(false) end\n\tself:Idle()\nend\n",
       "\tself:Idle()\nend\n",
       "look-warchief: the soot stays under the words with nobody owed",
       expect="with nobody owed the soot stays up", script=S)

# --- the soot ---

mutate(LUA,
       "\t\t\ts.box:SetSize(lead + w + h * TAG_CAPS * 1.1, h)\n",
       "\t\t\ts.box:SetSize(lead + w * 0.5, h)\n",
       "look-warchief: the soot ends half way along the line",
       expect="the soot under the name runs from", script=S)

mutate(LUA,
       "\tself.sootFrame:SetFrameLevel(base + 3)\n",
       "\tself.sootFrame:SetFrameLevel(base + 1)\n",
       "look-warchief: the soot lies under the lights it is there to cover",
       expect="not over the lights", script=S)

mutate(LUA,
       "\t\tt:AddMaskTexture(self.coalMask)\n",
       "",
       "look-warchief: the coals fill the crest's whole square",
       expect="the coals are not cut to the crest's shape", script=S)

# --- a landing, a refusal ---

mutate(LUA,
       "\t\tPlayAll(self.landing)\n",
       "",
       "look-warchief: a buff lands and no drum beats",
       expect="a landing did not beat the drum", script=S)

mutate(LUA,
       "\t\tself:Sparks(self.cx, self.H / 2, self.bz * 2)\n",
       "",
       "look-warchief: a buff lands and no sparks fly",
       expect="a landing flew no sparks", script=S)

mutate(LUA,
       "\t\tAlpha(g, first * 0.15, second, 0.04, 3, nil, \"OUT\")\n\t\tAlpha(g, second, 0, 0.30, 4, nil, \"IN\")\n",
       "\t\tAlpha(g, first * 0.15, 0, 0.34, 3, nil, \"IN\")\n",
       "look-warchief: the drum beats once",
       expect="the drum beats 1 times", script=S)

mutate(LUA,
       "\tif kind ~= \"cast\" then return end\n",
       "\tif kind ~= \"cast\" and kind ~= \"sent\" then return end\n",
       "look-warchief: the drum beats for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate(LUA,
       "\t\t\tPlayAll(self.refusal)\n",
       "",
       "look-warchief: a refusal leaves the brand unblinking",
       expect="a refusal did not blink the brand", script=S)

mutate(LUA,
       "\tColour(self.brand, SPENT[1], SPENT[2], SPENT[3])\n\tself.crest:SetDesaturated(true)\n",
       "\tColour(self.brand, SPENT[1], SPENT[2], SPENT[3])\n",
       "look-warchief: a refusal leaves the crest its red",
       expect="a refusal did not leave the crest cold", script=S)

mutate(LUA,
       "\tself.tusks[2]:SetTexCoord(1, 0, 0, 1)\n",
       "",
       "look-warchief: two left tusks",
       expect="the right tusk is not the left one's mirror", script=S)

# --- the list ---

mutate(LUA,
       "\tself.spikes:SetShown(self.spikesOK and not above)\n",
       "\tself.spikes:SetShown(self.spikesOK)\n",
       "look-warchief: the spikes stand in a list hung over the panel",
       expect="the spikes stand in it", script=S)

mutate(LUA,
       "\t\tif self.bannerOK then x1 = W - self.bannerRoom - 1 end\n",
       "",
       "look-warchief: the list runs under the banner",
       expect="runs under the banner", script=S)

# --- light ---

mutate(LUA,
       "\tself.crestGlow = tex(art, \"BORDER\", 4, \"CrestGlow\")\n",
       "\tself.crestGlow = tex(art, \"BORDER\", 4, \"CrestGlow\", \"ADD\")\n",
       "look-warchief: the crest's resting glow additive",
       expect="a light that rests lit is additive", script=S)

mutate(LUA,
       "local BANNER_FPS, SPARK_FPS = 9, 30\n",
       "local BANNER_FPS, SPARK_FPS = 9, 12\n",
       "look-warchief: the sparks burn for over a second",
       expect="stays lit", script=S)

# --- at rest ---

mutate(LUA,
       "\t\tif not self.bannerSheet:IsPlaying() then self.bannerSheet:Play() end\n",
       "",
       "look-warchief: the banner hangs still at rest",
       expect="at rest on Full the banner hangs still", script=S)

mutate(LUA,
       "\tlocal on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and kit.FullEffects() and kit.button:IsShown()) and true or false\n",
       "look-warchief: the banner stirs in a fight",
       expect="in a fight the look still moves", script=S)

mutate(LUA,
       "\tlocal on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and kit.button:IsShown()) and true or false\n",
       "look-warchief: the banner stirs on Calm",
       expect="on Calm the look still moves", script=S)

mutate(LUA,
       "\tif name == self.greeted then return end\n",
       "",
       "look-warchief: the same face greeted at every scan",
       expect="a repaint of the same face greeted again", script=S)

# --- Calm ---

mutate(LUA,
       "\t\tif full and self.crestOK then\n\t\t\tself:StopLights()\n",
       "\t\tif self.crestOK then\n\t\t\tself:StopLights()\n",
       "look-warchief: the crest struck on Calm",
       expect="on Calm the crest was struck", script=S)

# --- a fight ---

mutate(LUA,
       "\t\tt:SetDesaturated(on or (t == self.crest and self.refused) or false)\n",
       "\t\tt:SetDesaturated((t == self.crest and self.refused) or false)\n",
       "look-warchief: the slab keeps its colour in a fight",
       expect="in a fight the slab keeps its colour", script=S)

mutate(LUA,
       "\tself.baked = { self.frame, self.tusks[1], self.tusks[2], self.spikes, self.banner, self.crest }\n",
       "\tself.baked = { self.frame, self.tusks[1], self.tusks[2], self.spikes, self.banner, self.crest, self.brand }\n",
       "look-warchief: a fight dulls the brand with the iron",
       expect="in a fight the brand lost the reason's colour", script=S)

# --- the layout ---

mutate(LUA,
       "\tlocal textX = showIcon and (frameRight + reach + TEXT_GAP) or BARE_GAP\n",
       "\tlocal textX = showIcon and (frameRight + TEXT_GAP) or BARE_GAP\n",
       "look-warchief: the words start under the right tusk",
       expect="under a tusk that reaches", script=S)

mutate(LUA,
       "\tlocal cx, cy = reach + bz / 2, H / 2\n",
       "\tlocal cx, cy = bz / 2, H / 2\n",
       "look-warchief: the left tusk off the panel",
       expect="the left tusk passes the panel's left edge", script=S)

# --- the Lua and the generator ---

mutate(LUA,
       "local SOOT = 0.84\n",
       "local SOOT = 0.50\n",
       "look-warchief: the soot's darkness disagrees with the generator",
       expect="SOOT is", script=S)

mutate(LUA,
       "local RING_PEAK, RING_EDGE = 0.773, 0.914\n",
       "local RING_PEAK, RING_EDGE = 0.773, 0.80\n",
       "look-warchief: the ring's reach understated",
       expect="the ring's peak and reach are not the ones the generator prints", script=S)

mutate(GEN,
       "SEED = 6200\n",
       "SEED = 6201\n",
       "look-warchief: the art drawn from another seed",
       expect="does not match the file that ships", script=S)

mutate(GEN,
       "TUSK_EDGE = 0.40       # where the frame's edge lies in the tusk's file, from its outer side\n",
       "TUSK_EDGE = 0.45       # where the frame's edge lies in the tusk's file, from its outer side\n",
       "look-warchief: the tusk's place disagrees with the Lua",
       expect="TUSK_EDGE is", script=S)

# --- the review's fixes: the shadows, the paint, the reason line ---

mutate(LUA,
       "\tEach(self.listShadow, \"SetShown\", list ~= nil)\n",
       "\tEach(self.listShadow, \"SetShown\", true)\n",
       "look-warchief: the list's shadow left behind when the list goes",
       expect="with the list gone its shadow stays", script=S)

mutate(LUA,
       "\tPlacePieces(self.shadow, art, (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 3, W + SHADOW_OUT + 1, H + SHADOW_OUT + 2, SHADOW_C)\n",
       "\tPlacePieces(self.shadow, art, (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 3, W + SHADOW_OUT + 1, (list and list[4] or H) + SHADOW_OUT + 2, SHADOW_C)\n",
       "look-warchief: one shadow round the slab and the list, black beside the list",
       expect="black beside the list", script=S)

mutate(LUA,
       "\tlocal paintH = math.max(3, math.min(RIM * su * 2.0, PAINT_MAX))\n",
       "\tlocal paintH = math.max(3, RIM * su * 2.0)\n",
       "look-warchief: the paint floods the foot of a tall slab",
       expect="a flood and not a daub", script=S)

mutate(LUA,
       "\tsr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)\n",
       "\tsr, sg, sb = kit.Legible(sr, sg, sb, 4.5)\n",
       "look-warchief: the reason line held only to 4.5",
       expect="the reason line stands at", script=S)

mutate(LUA,
       "\tlocal vr, vg, vb = kit.Legible(o[1], o[2], o[3], SUB_CONTRAST)\n",
       "\tlocal vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)\n",
       "look-warchief: the verdict held only to 4.5",
       expect="a refusal: the reason line stands at", script=S)
