# Mutations for the Fel look (Looks/Fel.lua, Looks/Looks.lua, Manners.toc,
# tools/make_fel_textures.py): registered and loaded, round whatever the
# switch says, the marker's carriers and the shard's own violet, the runes
# lit one after another, the circle turning as one about its middle, the three
# breaths, the gout and the bolt, the refusal, the gout keeping to the panel
# under a list, no additive light at rest, the fire burning only at rest on
# Full with the prompt up, Calm, a fight, the words past the circle and the
# tags left of the horns, and the Lua and the generator agreeing. Each is
# caught by the scenario in tests/scenarios/look-fel.lua that names it.

S = "runscenarios.py"

# --- registered ---

mutate("Looks/Looks.lua",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true }\n",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true }\n",
       "look-fel: the round switch live on the summoning circle",
       expect="fel is not in roundAlways", script=S)

mutate("Manners.toc",
       "Looks\\Lightbringer.lua\nLooks\\Fel.lua\n",
       "Looks\\Lightbringer.lua\n",
       "look-fel: the toc does not load the look",
       expect="look-fel: it is registered, in the toc, and translated", script=S)

mutate("Looks/Fel.lua",
       "\torder = 9.5,\n",
       "\torder = 11,\n",
       "look-fel: after Glass in the picker",
       expect="fel is not after Lightbringer and before Glass", script=S)

# --- round ---

mutate("Looks/Fel.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-fel: the cooldown swept square over the circle",
       expect="the cooldown's sweep is not cut round", script=S)

mutate("Looks/Fel.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-fel: the round mask left on the next look's icon",
       expect="look-fel: every state paints on", script=S)

mutate("Looks/Fel.lua",
       "\tself.active = nil\n\tself.flow:StopAll()\n",
       "\tself.active = nil\n",
       "look-fel: the fire still burning under the next look",
       expect="under another look, still running", script=S)

# --- the marker ---

mutate("Looks/Fel.lua",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "look-fel: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate("Looks/Fel.lua",
       "\tif not stripe then gr, gg, gb = SOUL[1], SOUL[2], SOUL[3] end\n",
       "\tif not stripe then gr, gg, gb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "look-fel: the shard a pale green where the marker does not colour it",
       expect="the shard is coloured", script=S)

mutate("Looks/Fel.lua",
       "\tself.vein:SetVertexColor(vr, vg, vb, VEIN_ALPHA)\n",
       "\tself.vein:SetVertexColor(cr, cg, cb, VEIN_ALPHA)\n",
       "look-fel: the vein coloured by the icon's marker",
       expect="the vein is", script=S)

# --- the runes ---

mutate("Looks/Fel.lua",
       "\t\tself.runeLights[k] = anim(Fade(t, RUNE_REST, RUNE_LIT, RUNE_UP, (k - 1) * RUNE_STEP))\n",
       "\t\tself.runeLights[k] = anim(Fade(t, RUNE_REST, RUNE_LIT, RUNE_UP, 0))\n",
       "look-fel: the eight runes lit at once",
       expect="waits 0.00 s for its turn", script=S)

mutate("Looks/Fel.lua",
       "\t\tt:SetTexCoord(u - RUNE_BOX / 2, u + RUNE_BOX / 2, v - RUNE_BOX / 2, v + RUNE_BOX / 2)\n",
       "\t\tt:SetTexCoord(0, 1, 0, 1)\n",
       "look-fel: every rune drawn from the whole file",
       expect="the runes are not each cut from their own place", script=S)

mutate("Looks/Fel.lua",
       "\t\tif full and not self.refused then\n\t\t\tself:StopLights()\n\t\t\tStopAll(self.calm)\n\t\t\tself:Runes(RUNE_REST, SIGIL_REST)\n\t\t\tPlayAll(self.arrive)\n",
       "\t\tif full and not self.refused then\n\t\t\tself:StopLights()\n\t\t\tStopAll(self.calm)\n\t\t\tself:Runes(RUNE_REST, SIGIL_REST)\n",
       "look-fel: a favour arriving lights nothing",
       expect="look-fel: a favour arriving lights the runes one after another", script=S)

# --- the turn and the breath ---

mutate("Looks/Fel.lua",
       "\t\tif turn.SetOrigin then turn:SetOrigin(\"CENTER\", -dx, dy) end\n",
       "\t\tif turn.SetOrigin then turn:SetOrigin(\"CENTER\", 0, 0) end\n",
       "look-fel: each rune turning about its own middle",
       expect="not the circle's middle", script=S)

mutate("Looks/Fel.lua",
       "\tfor k, t in ipairs(self.runes) do self.turns[k] = anim(Turn(t, 360, TURN_SECONDS)) end\n",
       "\tfor k, t in ipairs(self.runes) do self.turns[k] = anim(Turn(t, -360, TURN_SECONDS)) end\n",
       "look-fel: the circle turning with the sun",
       expect="turns with the sun", script=S)

mutate("Looks/Fel.lua",
       "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n\t\t\tif gen ~= Fel.pulseGen or not Fel.active then return end\n",
       "\t\tC_Timer.After(BREATHS * BREATH * 20, function()\n\t\t\tif gen ~= Fel.pulseGen or not Fel.active then return end\n",
       "look-fel: the breath never held",
       expect="after three breaths, breath", script=S)

mutate("Looks/Fel.lua",
       "\tStopAll(self.runeLights)\n\tself.sigilLight:Stop()\n\tself:TurnCircle(false)\n\tself.bloom:SetAlpha(0)\n",
       "\tStopAll(self.runeLights)\n\tself.sigilLight:Stop()\n\tself.bloom:SetAlpha(0)\n",
       "look-fel: the circle turning on with nobody owed",
       expect="nobody owed, and rune", script=S)

# --- the flourishes ---

mutate("Looks/Fel.lua",
       "\t\tself.goutAnim:Play()\n\t\tself.goutSheet:Play()\n",
       "\t\tself.goutAnim:Play()\n",
       "look-fel: the gout lit and its frames never played",
       expect="a landing did not play the gout's frames", script=S)

mutate("Looks/Fel.lua",
       "\tif self.boltOK then\n\t\tPlayAll({ self.boltAnim, self.hotAnim, self.strikeAnim })\n",
       "\tif self.boltOK then\n\t\tPlayAll({ self.hotAnim, self.strikeAnim })\n",
       "look-fel: the shard struck by no bolt",
       expect="a landing threw no bolt", script=S)

mutate("Looks/Fel.lua",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n\tif kind ~= \"cast\" then return end\n",
       "\t-- Nothing for a cast nobody confirmed: a flourish is a claim.\n",
       "look-fel: a gout for a cast nobody confirmed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Fel.lua",
       "\tlocal burn = on and not self.refused\n",
       "\tlocal burn = on\n",
       "look-fel: the fire burning on after a refusal",
       expect="after a refusal the fire still burns", script=S)

mutate("Looks/Fel.lua",
       "\tself:Runes(RUNE_DARK, RUNE_DARK)\n\tself:TurnCircle(false)\n",
       "\tself:Runes(RUNE_DARK, RUNE_DARK)\n",
       "look-fel: the circle turning on after a refusal",
       expect="after a refusal rune", script=S)

mutate("Looks/Fel.lua",
       "\t\t\tPlayAll(self.refusal)\n\t\t\tPlayAll(self.aftermath)\n",
       "\t\t\tPlayAll(self.refusal)\n",
       "look-fel: a refusal without its smoke",
       expect="a refusal raised no smoke", script=S)

mutate("Looks/Fel.lua",
       "\tif above then goutH = math.min(goutH, goutFoot) end\n",
       "",
       "look-fel: the gout leaping over the list",
       expect="with the list above, the gout reaches", script=S)

mutate("Looks/Fel.lua",
       "\tAlpha(g, 1, 1, 0.37, 2)\n\tAlpha(g, 1, 0, 0.14, 3, nil, \"IN\")\n\tPark(g, region, 0)\n",
       "\tAlpha(g, 1, 1, 0.37, 2)\n\tAlpha(g, 1, 0, 0.14, 3, nil, \"IN\")\n\tPark(g, region, 1)\n",
       "look-fel: the gout left lit",
       expect="additive light left on", script=S)

mutate("Looks/Fel.lua",
       "\tself.boltAnim = anim(Runner(self.bolt, 0.04, 0.26, 1, \"IN\"))\n",
       "\tself.boltAnim = anim(Runner(self.bolt, 0.04, 0.96, 1, \"IN\"))\n",
       "look-fel: a bolt that takes a second to fly",
       expect="the landing's light", script=S)

# --- at rest ---

mutate("Looks/Fel.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-fel: the fire's frames playing through a fight",
       expect="in a fight, still running", script=S)

mutate("Looks/Fel.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-fel: the fire burning on Calm",
       expect="on Calm, still running", script=S)

mutate("Looks/Fel.lua",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-fel: the fire burning under a prompt that is down",
       expect="with the prompt down, still running", script=S)

mutate("Looks/Fel.lua",
       "\t\t\t-- Started together, so every tile shows the one frame and they meet.\n\t\t\tif not h:IsPlaying() then h:Play() end\n",
       "\t\t\t-- Started together, so every tile shows the one frame and they meet.\n\t\t\tif not h:IsPlaying() and i == 1 then h:Play() end\n",
       "look-fel: one tile of the fire burning, the rest a still",
       expect="at rest on Full, not running: tile 2 of the fire", script=S)

mutate("Looks/Fel.lua",
       "\t-- Asked afresh: the fire's tiles may be other tiles now.\n\tself.idleState = nil\n",
       "\t-- Asked afresh: the fire's tiles may be other tiles now.\n",
       "look-fel: a restyle that leaves the fire as the last one had it",
       expect="back on Full, not running again", script=S)

# --- Calm and the fight ---

mutate("Looks/Fel.lua",
       "\t\t-- Calm: one fade up to the held light, and nothing loops or turns.\n\t\tself:TurnCircle(false)\n",
       "\t\t-- Calm: one fade up to the held light, and nothing loops or turns.\n\t\tself:TurnCircle(true)\n",
       "look-fel: the circle turning on Calm",
       expect="on Calm rune", script=S)

mutate("Looks/Fel.lua",
       "\treturn self.combat and 0 or (self.refused and FIRE_GUTTERED or FIRE_ALPHA)\n",
       "\treturn self.refused and FIRE_GUTTERED or FIRE_ALPHA\n",
       "look-fel: the fire burning on in a fight",
       expect="in a fight the fire burns on", script=S)

mutate("Looks/Fel.lua",
       "\t\tStopAll(self.aftermath)\n\t\tself:Runes(RUNE_COMBAT, RUNE_COMBAT)\n",
       "\t\tStopAll(self.aftermath)\n",
       "look-fel: the runes lit through a fight",
       expect="in a fight the runes stay lit", script=S)

# --- the layout ---

mutate("Looks/Fel.lua",
       "\tlocal textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP\n",
       "\tlocal textX = showIcon and (cx + TEXT_GAP) or BARE_GAP\n",
       "look-fel: the words under the circle",
       expect="under a circle that reaches", script=S)

mutate("Looks/Fel.lua",
       "\tself.chipInset = math.ceil(W - forkX - FORK_ROOT * su) + 2\n",
       "\tself.chipInset = 18\n",
       "look-fel: the tags over the horns",
       expect="the tags would lie over the horns", script=S)

mutate("Looks/Fel.lua",
       "\tlocal over = s.fork and FORK_OVER * su or 0\n",
       "\tlocal over = 0\n",
       "look-fel: the horns squashed into the slab's height",
       expect="do not stand proud of the slab", script=S)

# --- the generator ---

mutate("tools/make_fel_textures.py",
       "RUNE_R = 0.80 ",
       "RUNE_R = 0.70 ",
       "look-fel: the generator's runes on another ring than the look's",
       expect="RUNE_R is 0.80 in the Lua and 0.70 in the generator", script=S)

mutate("Looks/Fel.lua",
       "local FIRE_FRAMES = 16\n",
       "local FIRE_FRAMES = 12\n",
       "look-fel: the look playing fewer frames than the fire's sheet holds",
       expect="FIRE_FRAMES is 12 in the Lua and 16 in the generator", script=S)

mutate("tools/make_fel_textures.py",
       "SEED = 6601\n",
       "SEED = 6602\n",
       "look-fel: the generator drawing other art than ships",
       expect="does not match the file that ships", script=S)
