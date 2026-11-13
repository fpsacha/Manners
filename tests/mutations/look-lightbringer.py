# Mutations for the Lightbringer look (Looks/Lightbringer.lua, Looks/Looks.lua,
# tools/make_lightbringer_textures.py): round whatever the switch says, the
# marker's carriers, the pillar, the three breaths, the blessing's wings and
# motes, the refusal, the Light keeping to the panel under a list, no additive
# light at rest, the sun turning as one, Calm, a fight, the words past the
# rays, and the Lua and the generator agreeing. Each is caught by the scenario
# in tests/scenarios/look-lightbringer.lua that names it.

S = "runscenarios.py"

# --- registered ---

mutate("Looks/Looks.lua",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true }\n",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, fel = true, wild = true }\n",
       "lightbringer: the round switch live on the sun",
       expect="lightbringer is not in roundAlways", script=S)

# --- round ---

mutate("Looks/Lightbringer.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "lightbringer: the cooldown swept square over the sun",
       expect="the cooldown's sweep is not cut round", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "lightbringer: the round mask left on the next look's icon",
       expect="look-lightbringer: every state paints on", script=S)

# --- the marker ---

mutate("Looks/Lightbringer.lua",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "lightbringer: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "lightbringer: the nimbus coloured with the marker on the stripe",
       expect="the nimbus is coloured", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.gem:SetVertexColor(vr, vg, vb, 1)\n",
       "\tself.gem:SetVertexColor(cr, cg, cb, 1)\n",
       "lightbringer: the gem follows the nimbus, not the stripe",
       expect="the gem is", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal wr = SUNLIGHT[1] + (cr - SUNLIGHT[1]) * WARM_REASON\n",
       "\tlocal wr = cb\n",
       "lightbringer: the rays' second tone cold",
       expect="the rays' second tone is not warm", script=S)

# --- a favour arriving ---

mutate("Looks/Lightbringer.lua",
       "\t\tif full and self.kit.icon:IsShown() then\n\t\t\tself:StopLights()\n\t\t\tPlayAll(self.arrive)\n",
       "\t\tif false then\n\t\t\tself:StopLights()\n\t\t\tPlayAll(self.arrive)\n",
       "lightbringer: no pillar for a favour",
       expect="a favour arriving brought no pillar down", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal pillarUp = above and 0 or H * PILLAR_UP\n",
       "\tlocal pillarUp = 0\n",
       "lightbringer: the pillar starts at the panel's top",
       expect="the pillar does not come from above the panel", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal pillarUp = above and 0 or H * PILLAR_UP\n",
       "\tlocal pillarUp = H * PILLAR_UP\n",
       "lightbringer: the pillar over the list hung above",
       expect="with the list above, the pillar reaches", script=S)

# --- the owed breath ---

mutate("Looks/Lightbringer.lua",
       "\t\t\t\tLightbringer:HoldPulse(true)\n\t\t\t\t-- Settled: the gem says so, once.\n",
       "\t\t\t\t-- Settled: the gem says so, once.\n",
       "lightbringer: the sun breathes for ever",
       expect="after three breaths, breath", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.nimbus:SetAlpha(spent and NIMBUS_HELD or NIMBUS_REST)\n",
       "\tself.nimbus:SetAlpha(NIMBUS_REST)\n",
       "lightbringer: the nimbus dims after its breaths",
       expect="after three breaths the nimbus is at", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif not full then\n\t\t-- Calm: one fade up to the held light, and nothing loops.\n",
       "\tif false then\n\t\t-- Calm: one fade up to the held light, and nothing loops.\n",
       "lightbringer: the breath loops on Calm",
       expect="look-lightbringer: Calm keeps to fades", script=S)

# --- a landing, a refusal ---

mutate("Looks/Lightbringer.lua",
       "\t\tif self.wingsOK then PlayAll(self.wingAnims) end\n",
       "",
       "lightbringer: a blessing without wings",
       expect="a landing did not spread both wings", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.wingsOK = showIcon and not above\n",
       "\tself.wingsOK = showIcon\n",
       "lightbringer: the wings spread over the list hung above",
       expect="with the list above, a landing spread the wings over it", script=S)

mutate("Looks/Lightbringer.lua",
       "\t\tif i == 2 then t:SetTexCoord(1, 0, 0, 1) end\n",
       "",
       "lightbringer: two right wings",
       expect="the second wing is not the first's mirror", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif self.motesOK then PlayAll(self.moteAnims) end\n",
       "",
       "lightbringer: a blessing without motes",
       expect="a landing did not raise the motes", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif kind ~= \"cast\" then return end\n\tself:StopLights()\n",
       "\tself:StopLights()\n",
       "lightbringer: a cast nobody confirmed is blessed",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.nimbus:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1)\n\tself.rays:SetDesaturated(true)\n",
       "\tself.rays:SetDesaturated(true)\n",
       "lightbringer: a refusal leaves the nimbus lit",
       expect="a refusal did not leave the nimbus spent", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.nimbus:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1)\n\tself.rays:SetDesaturated(true)\n",
       "\tself.nimbus:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1)\n",
       "lightbringer: a refusal leaves the rays gold",
       expect="a refusal did not grey the rays", script=S)

# --- no additive light at rest ---

mutate("Looks/Lightbringer.lua",
       "\tself.raysWarm = tex(art, \"ARTWORK\", -4, \"RaysLight\")\n",
       "\tself.raysWarm = tex(art, \"ARTWORK\", -4, \"RaysLight\", \"ADD\")\n",
       "lightbringer: the rays' second tone additive at rest",
       expect="additive", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.38))\n",
       "\tself.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.60))\n",
       "lightbringer: the blessing's flash lit past its time",
       expect="stays lit", script=S)

# --- the sun at rest ---

mutate("Looks/Lightbringer.lua",
       "\t\tanim(Turn(self.raysHot, RAY_TURN, RAY_SECONDS)),\n",
       "\t\tanim(Turn(self.raysHot, RAY_TURN, RAY_SECONDS * 2)),\n",
       "lightbringer: the rays' flash turns at its own speed",
       expect="turns at its own speed", script=S)

mutate("Looks/Lightbringer.lua",
       "local RAY_TURN, RAY_SECONDS = 45, 16\n",
       "local RAY_TURN, RAY_SECONDS = 40, 16\n",
       "lightbringer: the sun jumps back at each turn's end",
       expect="does not turn an eighth", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects()\n\tlocal sun = on and self.kit.icon:IsShown()\n",
       "\tlocal on = self.active and not self.combat\n\tlocal sun = on and self.kit.icon:IsShown()\n",
       "lightbringer: the sun turns on Calm",
       expect="on Calm, light", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects()\n\tlocal sun = on and self.kit.icon:IsShown()\n",
       "\tlocal on = self.active and self.kit.FullEffects()\n\tlocal sun = on and self.kit.icon:IsShown()\n",
       "lightbringer: the sun turns in a fight",
       expect="in a fight, light", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif name == self.greeted then return end\n",
       "",
       "lightbringer: the same face greeted at every scan",
       expect="a repaint of the same face greeted again", script=S)

# --- a fight ---

mutate("Looks/Lightbringer.lua",
       "\tEach(self.body, \"SetDesaturated\", on)\n",
       "",
       "lightbringer: the plate keeps its colour in a fight",
       expect="in a fight the plate keeps its colour", script=S)

# --- the layout ---

mutate("Looks/Lightbringer.lua",
       "\tlocal textX = showIcon and math.max(bezelRight + TEXT_GAP, rayRight + 2) or BARE_GAP\n",
       "\tlocal textX = showIcon and (bezelRight + TEXT_GAP) or BARE_GAP\n",
       "lightbringer: the words start under a ray",
       expect="under a ray that reaches", script=S)

# --- the Lua and the generator ---

mutate("Looks/Lightbringer.lua",
       "local RAY_SCALE = 1.5\n",
       "local RAY_SCALE = 1.4\n",
       "lightbringer: the rays' size disagrees with the generator",
       expect="RAY_SCALE is", script=S)

mutate("tools/make_lightbringer_textures.py",
       "SEED_PLATE, SEED_SUN, SEED_TAG, SEED_GLYPH, SEED_GEM = 5101, 5102, 5103, 5104, 5105\n",
       "SEED_PLATE, SEED_SUN, SEED_TAG, SEED_GLYPH, SEED_GEM = 5101, 5199, 5103, 5104, 5105\n",
       "lightbringer: the sun's gold drawn from another seed",
       expect="does not match the file that ships", script=S)
