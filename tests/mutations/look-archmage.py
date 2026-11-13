# Mutations for the Archmage look (Looks/Archmage.lua, Looks/Looks.lua,
# tools/make_archmage_textures.py): the hexagon whatever the round switch
# says, six charges, the marker's carriers, the arrival's chase, the owed
# wave's three turns, the landing's lightning frame by frame, the refusal's
# unwinding, no additive light at rest, Calm, a fight, the setting inside the
# crystal, and the Lua and the generator agreeing. Each is caught by the
# scenario in tests/scenarios/look-archmage.lua that names it.

S = "runscenarios.py"

# --- registered ---

mutate("Looks/Looks.lua",
       "Looks.roundAlways = { ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true }\n",
       "Looks.roundAlways = { ribbon = true, letter = true, lightbringer = true, fel = true, wild = true }\n",
       "archmage: the round switch live on a hexagon",
       expect="archmage is not in roundAlways", script=S)

# --- the hexagon ---

mutate("Looks/Archmage.lua",
       "\t\tself.mask:Show()\n",
       "\t\tself.mask:Hide()\n",
       "archmage: the icon's hexagon never shown",
       expect="look-archmage: the icon is a hexagon, round or not", script=S)

mutate("Looks/Archmage.lua",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "archmage: the cooldown swept square over the hexagon",
       expect="the cooldown's sweep is not cut to the hexagon", script=S)

mutate("Looks/Archmage.lua",
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "archmage: the hexagon left on the next look's icon",
       expect="look-archmage: every state paints on", script=S)

# --- six charges ---

mutate("Looks/Archmage.lua",
       "\t{ \"ChargeT\", 0, 1, 1, 0 }, { \"ChargeS\", 1, 0, 1, 0 }, { \"ChargeS\", 1, 0, 0, 1 },\n",
       "\t{ \"ChargeT\", 0, 1, 0, 1 }, { \"ChargeS\", 1, 0, 1, 0 }, { \"ChargeS\", 1, 0, 0, 1 },\n",
       "archmage: the bottom charge drawn on the top's facet",
       expect="are the same facet", script=S)

# --- the marker ---

mutate("Looks/Archmage.lua",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "archmage: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate("Looks/Archmage.lua",
       "\tif not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "archmage: the charges coloured with the marker on the stripe",
       expect="the charges are coloured", script=S)

mutate("Looks/Archmage.lua",
       "\tif not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "archmage: the vein coloured with the marker on the icon",
       expect="the vein is coloured", script=S)

# --- a favour arriving ---

mutate("Looks/Archmage.lua",
       "\t\tself.arrive[i] = anim(Flash(t, 0.85, 0.05, 0.20, 0, 0.04 * (i - 1)))\n",
       "\t\tself.arrive[i] = anim(Flash(t, 0.85, 0.05, 0.20, 0, 0))\n",
       "archmage: the six charges flash at once on arrival",
       expect="does not wait dark for its turn", script=S)

mutate("Looks/Archmage.lua",
       "\t\tif full and self.kit.icon:IsShown() then\n\t\t\tself:StopLights()\n",
       "\t\tif self.kit.icon:IsShown() then\n\t\t\tself:StopLights()\n",
       "archmage: the arrival's lights on Calm",
       expect="on Calm the arrival's lights played", script=S)

mutate("Looks/Archmage.lua",
       "\t\t\tif self.runOK and self.veinOK then\n\t\t\t\tself.arriveRun:Play()\n",
       "\t\t\tif false then\n\t\t\t\tself.arriveRun:Play()\n",
       "archmage: no light along the vein on arrival",
       expect="no light ran along the vein", script=S)

# --- the owed wave ---

mutate("Looks/Archmage.lua",
       "\t\t\t\tArchmage:HoldPulse(true)\n\t\t\t\t-- Settled: the crystal says so, once.\n",
       "\t\t\t\t-- Settled: the crystal says so, once.\n",
       "archmage: the wave goes round for ever",
       expect="after three turns group", script=S)

mutate("Looks/Archmage.lua",
       "\tfor _, t in ipairs(self.charges) do t:SetAlpha(spent and CHARGE_HELD or CHARGE_REST) end\n",
       "\tfor _, t in ipairs(self.charges) do t:SetAlpha(CHARGE_REST) end\n",
       "archmage: the charges go dim after their turns",
       expect="after three turns charge", script=S)

mutate("Looks/Archmage.lua",
       "\tif not full then\n\t\t-- Calm: one fade up to the held light, and nothing loops.\n",
       "\tif false then\n\t\t-- Calm: one fade up to the held light, and nothing loops.\n",
       "archmage: the wave loops on Calm",
       expect="look-archmage: Calm keeps to fades", script=S)

# --- a landing, a refusal ---

mutate("Looks/Archmage.lua",
       "\t\tPlayAll(self.arcAnims)\n",
       "",
       "archmage: a landing without its lightning",
       expect="did not play the lightning's four frames", script=S)

mutate("Looks/Archmage.lua",
       "\tif kind ~= \"cast\" then return end\n\tself:StopLights()\n",
       "\tself:StopLights()\n",
       "archmage: a cast nobody confirmed discharges the setting",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate("Looks/Archmage.lua",
       "\tfor _, t in ipairs(self.charges) do t:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1) end\n",
       "",
       "archmage: a refusal leaves the charges lit",
       expect="a refusal did not leave the charges spent", script=S)

mutate("Looks/Archmage.lua",
       "\t\tself.refusal[i] = anim(Flash(t, 0.8, 0.03, 0.12, 0, 0.04 * (#self.sparks - i)))\n",
       "\t\tself.refusal[i] = anim(Flash(t, 0.8, 0.03, 0.12, 0, 0.04 * (i - 1)))\n",
       "archmage: a refusal winds the same way as an arrival",
       expect="the sixth charge waits for its turn in a refusal", script=S)

# --- no additive light at rest ---

mutate("Looks/Archmage.lua",
       "\tself.halo = tex(art, \"ARTWORK\", -1, \"Halo\")\n",
       "\tself.halo = tex(art, \"ARTWORK\", -1, \"Halo\", \"ADD\")\n",
       "archmage: the halo additive at rest",
       expect="additive light left on", script=S)

mutate("Looks/Archmage.lua",
       "\tself.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.38))\n",
       "\tself.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.60))\n",
       "archmage: the landing's flash lit past its time",
       expect="stays lit", script=S)

# --- a fight ---

mutate("Looks/Archmage.lua",
       "\tEach(self.body, \"SetDesaturated\", on)\n",
       "",
       "archmage: the crystal keeps its colour in a fight",
       expect="in a fight the crystal keeps its colour", script=S)

# --- inside the crystal ---

mutate("Looks/Archmage.lua",
       "\tlocal bz = math.min(iconSize / ICON_FRAME, (H - 1) / (HEX_OUT * S3))\n",
       "\tlocal bz = iconSize / ICON_FRAME\n",
       "archmage: the setting taller than the crystal",
       expect="look-archmage: the setting and the lights stay inside the crystal", script=S)

# --- the Lua and the generator ---

mutate("Looks/Archmage.lua",
       "local TAG_CAPS = 0.5\n",
       "local TAG_CAPS = 0.4\n",
       "archmage: the tag's caps disagree with the generator",
       expect="TAG_CAPS is", script=S)

mutate("tools/make_archmage_textures.py",
       "SEED_BODY, SEED_BEZEL, SEED_TAG, SEED_ARCS, SEED_GLYPH = 4101, 4102, 4103, 4104, 4105\n",
       "SEED_BODY, SEED_BEZEL, SEED_TAG, SEED_ARCS, SEED_GLYPH = 4101, 4102, 4103, 4199, 4105\n",
       "archmage: the lightning drawn from another seed",
       expect="does not match the file that ships", script=S)

# --- the crystal at rest ---

mutate("Looks/Archmage.lua",
       "\tlocal on = self.active and self.idleOK and not self.combat and self.kit.FullEffects()\n",
       "\tlocal on = self.active and self.idleOK and not self.combat\n",
       "archmage: the crystal sparkles on Calm",
       expect="on Calm, light", script=S)

mutate("Looks/Archmage.lua",
       "\tlocal on = self.active and self.idleOK and not self.combat and self.kit.FullEffects()\n",
       "\tlocal on = self.active and self.idleOK and self.kit.FullEffects()\n",
       "archmage: the crystal sparkles in a fight",
       expect="in a fight, light", script=S)

mutate("Looks/Archmage.lua",
       "\t\tlocal t = tex(self.idleFrame, \"OVERLAY\", 1, \"Mote\")\n",
       "\t\tlocal t = tex(self.idleFrame, \"OVERLAY\", 1, \"Mote\", \"ADD\")\n",
       "archmage: the drifting lights additive at rest",
       expect="a light of the crystal at rest is additive", script=S)

mutate("Looks/Archmage.lua",
       "\tif name == self.greeted then return end\n",
       "",
       "archmage: the same face greeted at every scan",
       expect="a repaint of the same face greeted again", script=S)

mutate("Looks/Archmage.lua",
       "\tif name and not (entry.reason == \"owed\") then self:Greet() end\n",
       "",
       "archmage: nobody is greeted",
       expect="the first face on the panel was not greeted", script=S)

mutate("Looks/Archmage.lua",
       "\tlocal cx = half + math.max(3, math.min(H / (2 * S3) - half, SETTING_IN))\n",
       "\tlocal cx = math.max(H / (2 * S3), half + 3)\n",
       "archmage: a small setting out in the middle of a tall crystal",
       expect="units in from the point", script=S)
