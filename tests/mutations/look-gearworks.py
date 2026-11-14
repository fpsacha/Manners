# Mutations for the Gearworks look (Looks/Gearworks.lua,
# tools/make_gearworks_textures.py, Manners.toc): registered and last in the
# picker, round whatever the switch says and held inside the glass, the
# marker's carriers, the needle's six marks and its swing, the whistle, the
# three breaths with the tremble and the bubbles, the steam and the spinning
# cogs, the spark and the jam, nothing on the housing's top under a list, no
# additive light at rest, the cogs in mesh, Calm, a fight, the words clear of
# the gauge and the gearbox, and the Lua and the generator agreeing. Each is
# caught by the scenario in tests/scenarios/look-gearworks.lua that names it.

S = "runscenarios.py"
LUA = "Looks/Gearworks.lua"
GEN = "tools/make_gearworks_textures.py"

# --- registered ---

mutate("Manners.toc",
       "Looks\\Warchief.lua\nLooks\\Gearworks.lua\n",
       "Looks\\Warchief.lua\n",
       "look-gearworks: the toc does not load the look",
       expect="look-gearworks: it is registered and in the toc", script=S)

mutate(LUA,
       "\torder = 9.9,\n",
       "\torder = 9.6,\n",
       "look-gearworks: not the last of the looks in the picker",
       expect="gearworks is not after the other looks", script=S)

# --- round ---

mutate(LUA,
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
       "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(WHITE) end\n",
       "look-gearworks: the cooldown swept square under the glass",
       expect="the cooldown's sweep is not cut round", script=S)

mutate(LUA,
       "\tlocal icon = kit.icon\n\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n",
       "\tlocal icon = kit.icon\n\tif self.masked then\n",
       "look-gearworks: the round mask left on the next look's icon",
       expect="the round mask was left on the icon", script=S)

mutate(LUA,
       "\tlocal iconSize = math.max(8, math.min(p.iconSize or 30, gz * ICON_FRAME))\n",
       "\tlocal iconSize = math.max(8, p.iconSize or 30)\n",
       "look-gearworks: a large icon drawn over the dial",
       expect="across in a glass of", script=S)

mutate(LUA,
       "\tself.flow:StopAll()\n",
       "",
       "look-gearworks: the bubbles left drifting under the next look",
       expect="still move by Flow", script=S)

# --- the marker ---

mutate(LUA,
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
       "\tlocal mode = p.accentMode or \"icon\"\n\treturn true, true\n",
       "look-gearworks: both marks claimed whatever the marker",
       expect="AccentCarriers says", script=S)

mutate(LUA,
       "\tif not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "look-gearworks: the dial coloured with the marker on the stripe",
       expect="the dial is coloured", script=S)

mutate(LUA,
       "\tColour(self.tube, vr, vg, vb, TUBE_ALPHA)\n",
       "\tColour(self.tube, cr, cg, cb, TUBE_ALPHA)\n",
       "look-gearworks: the tube follows the dial, not the stripe",
       expect="the tube is", script=S)

mutate(LUA,
       "\tlocal wr = GASLIGHT[1] + (cr - GASLIGHT[1]) * WARM_REASON\n",
       "\tlocal wr = cb * 0.5\n",
       "look-gearworks: the dial's second tone cold",
       expect="the dial's second tone is not warm", script=S)

mutate(LUA,
       "\tself.mark = ring and MARK[reason] or ZERO\n",
       "\tself.mark = MARK[reason] or ZERO\n",
       "look-gearworks: the needle tells the reason with the marker off the dial",
       expect="the needle stands at", script=S)

# --- the needle ---

mutate(LUA,
       "local MARK = { nearby = -135, self = -81, group = -27, target = 27, asked = 81, owed = 135 }\n",
       "local MARK = { nearby = -135, self = -81, group = -27, target = 27, asked = 27, owed = 135 }\n",
       "look-gearworks: two reasons share a mark",
       expect="for asked the needle is sent to", script=S)

mutate(LUA,
       "\tif deg < 0 then l, r = r, l end\n",
       "",
       "look-gearworks: the left marks drawn on the right",
       expect="the needle is drawn at", script=S)

mutate(LUA,
       "\t\tg.out:SetDegrees(-(d + over))\n",
       "\t\tg.out:SetDegrees(-d)\n",
       "look-gearworks: the swing stops short of its mark",
       expect="the swing's turns add up to", script=S)

mutate(LUA,
       "\t\tlocal over = math.min(math.abs(d) * SWING.over, SWING.most) * (d < 0 and -1 or 1)\n",
       "\t\tlocal over = math.abs(d) * SWING.over * (d < 0 and -1 or 1)\n",
       "look-gearworks: a long swing carries the needle into the dial's foot",
       expect="does not pass its mark by a little", script=S)

mutate(LUA,
       "\tif self.needleAt and self.needleShown ~= self.needleAt then self:ShowNeedle(self.needleAt) end\n",
       "",
       "look-gearworks: the needle springs back when its swing ends",
       expect="its swing over, the needle is drawn at", script=S)

mutate(LUA,
       "\tif swing and from and self.active and not self.combat and self.kit.FullEffects() and self.kit.icon:IsShown() then\n",
       "\tif swing and from and self.active and not self.combat and self.kit.icon:IsShown() then\n",
       "look-gearworks: the needle swings on Calm",
       expect="on Calm the needle swung", script=S)

# --- a favour arriving ---

mutate(LUA,
       "\t\t\tif self.stackOK then Roll(self.whistleSheet, self.whistleAnim) end\n",
       "",
       "look-gearworks: a favour arrives and the vent says nothing",
       expect="a favour arriving did not whistle", script=S)

# --- owed ---

mutate(LUA,
       "local BREATHS, BREATH = 3, 1.25\n",
       "local BREATHS, BREATH = 5, 1.25\n",
       "look-gearworks: five breaths, not three",
       expect="after three breaths, breath", script=S)

mutate(LUA,
       "\t\tself.bubbleRun:Speed(BUBBLE_RUN, 0)\n\t\tself.trembling = true\n",
       "\t\tself.bubbleRun:Speed(BUBBLE_RUN, 0)\n",
       "look-gearworks: under pressure the needle stands still",
       expect="the needle does not tremble at its mark", script=S)

mutate(LUA,
       "\t\tself.bubbleRun:Speed(BUBBLE_RUN, 0)\n\t\tself.trembling = true\n",
       "\t\tself.trembling = true\n",
       "look-gearworks: under pressure the bubbles only drift",
       expect="the bubbles do not run along the tube", script=S)

mutate(LUA,
       "\tStopAll(self.pulse)\n\tself.trembling = nil\n\tself.trembleAnim:Stop()\n\tself.bubbleRun:Speed(BUBBLE_DRIFT, 0)\n\tself.dialWarm:SetAlpha(spent and WARM.held or 0)\n",
       "\tStopAll(self.pulse)\n\tself.bubbleRun:Speed(BUBBLE_DRIFT, 0)\n\tself.dialWarm:SetAlpha(spent and WARM.held or 0)\n",
       "look-gearworks: the needle trembles on after the breath is held",
       expect="after three breaths the needle still trembles", script=S)

# --- a landing ---

mutate(LUA,
       "\tif self.stackOK then Roll(self.steamSheet, self.steamAnim) end\n",
       "",
       "look-gearworks: a buff lands and no steam is let off",
       expect="a landing let no steam off", script=S)

mutate(LUA,
       "\t\tfor _, g in ipairs(self.turns) do g:Stop() end\n\t\tPlayAll(self.spins)\n",
       "\t\tfor _, g in ipairs(self.turns) do g:Stop() end\n",
       "look-gearworks: a buff lands and the cogs do not spin",
       expect="a landing did not spin cog", script=S)

mutate(LUA,
       "local SPIN_TEETH, SPIN_SECONDS = 6, 0.66\n",
       "local SPIN_TEETH, SPIN_SECONDS = 5, 0.66\n",
       "look-gearworks: the spin ends between two teeth",
       expect="not six teeth", script=S)

mutate(LUA,
       "\t\tspin:SetScript(\"OnFinished\", function() Gearworks:Idle() end)\n",
       "",
       "look-gearworks: spun down, the cogs stand until the next scan",
       expect="did not go back to its round", script=S)

mutate(LUA,
       "\tif kind ~= \"sent\" then self:SetNeedle(ZERO, true) end\n",
       "\tif kind == \"failed\" then self:SetNeedle(ZERO, true) end\n",
       "look-gearworks: the steam let off and the needle still up",
       expect="a landing did not drop the needle", script=S)

mutate(LUA,
       "\tif kind ~= \"cast\" then return end\n",
       "\tif kind == \"failed\" then return end\n",
       "look-gearworks: a cast nobody confirmed lets the steam off",
       expect="a cast nobody confirmed played a flourish", script=S)

mutate(LUA,
       "\tself.jammed = nil\n\tself:SetNeedle(self.mark or ZERO, true)\n",
       "\tself.jammed = nil\n",
       "look-gearworks: the outcome over, the needle stays at nothing",
       expect="the needle did not climb back", script=S)

# --- a refusal ---

mutate(LUA,
       "\t\tif self.contactsOK then Roll(self.sparkSheet, self.sparkAnim) end\n",
       "",
       "look-gearworks: a refusal and no spark",
       expect="a refusal struck no spark", script=S)

mutate(LUA,
       "\t\tself.jammed = true\n\t\tself:Spend()\n",
       "\t\tself:Spend()\n",
       "look-gearworks: a refusal and the cogs turn on",
       expect="a refusal left cog", script=S)

mutate(LUA,
       "\tColour(self.dial, SPENT[1], SPENT[2], SPENT[3])\n",
       "",
       "look-gearworks: a refusal leaves the dial lit",
       expect="a refusal did not leave the dial grey", script=S)

mutate(LUA,
       "\t\tRotate(jolt, tooth * JOLT.teeth, JOLT.forth, 2, \"IN_OUT\")\n",
       "\t\tRotate(jolt, tooth * JOLT.teeth * 2, JOLT.forth, 2, \"IN_OUT\")\n",
       "look-gearworks: the kick leaves the cogs out of mesh",
       expect="kick does not end where it began", script=S)

mutate(LUA,
       "\t\tif self.boxed then PlayAll(self.jolts) end\n",
       "",
       "look-gearworks: a refusal and the cogs do not kick",
       expect="a refusal did not kick the cogs back", script=S)

# --- the list above ---

mutate(LUA,
       "\tself.stackOK = not above and sx - ss / 2 >= textX + 2\n",
       "\tself.stackOK = sx - ss / 2 >= textX + 2\n",
       "look-gearworks: the vent stands in the list hung over the panel",
       expect="with the list above, the", script=S)

# --- no additive light at rest ---

mutate(LUA,
       "\tself.steam = tex(self.lightFrame, \"OVERLAY\", 3, \"Steam\")\n",
       "\tself.steam = tex(self.lightFrame, \"OVERLAY\", 3, \"Steam\", \"ADD\")\n",
       "look-gearworks: the steam drawn as light",
       expect="look-gearworks: no additive light at rest", script=S)

mutate(LUA,
       "\tself.hotAnim = anim(Flash(self.dialHot, 0.6, 0.07, 0.38))\n",
       "\tself.hotAnim = anim(Flash(self.dialHot, 0.6, 0.07, 0.68))\n",
       "look-gearworks: the dial's flash outstays a flourish",
       expect="stays lit", script=S)

# --- the cogs ---

mutate(LUA,
       "\t{ file = \"GearB\", teeth = TEETH_B, at = MESH_B, way = -1 },\n",
       "\t{ file = \"GearB\", teeth = TEETH_B, at = MESH_B, way = 1 },\n",
       "look-gearworks: two meshed cogs turn the same way",
       expect="turns the wrong way for its place in the train", script=S)

mutate(LUA,
       "local TURN_TEETH, TURN_SECONDS = 2, 7\n",
       "local TURN_TEETH, TURN_SECONDS = 3, 7\n",
       "look-gearworks: a round that ends on another picture",
       expect="not two of its", script=S)

mutate(LUA,
       "\t\tlocal dist = GEAR_M * (TEETH_A + cog.teeth) / 2\n",
       "\t\tlocal dist = GEAR_M * (TEETH_A + cog.teeth) / 2 + 3\n",
       "look-gearworks: the cogs' axles too far apart to mesh",
       expect="the teeth would not meet", script=S)

mutate(LUA,
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()\n",
       "\tlocal on = self.active and self.kit.FullEffects() and self.kit.button:IsShown()\n",
       "look-gearworks: the cogs turn through a fight",
       expect="in a fight, light", script=S)

mutate(LUA,
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()\n",
       "\tlocal on = self.active and not self.combat and self.kit.button:IsShown()\n",
       "look-gearworks: the cogs turn on Calm",
       expect="on Calm, light", script=S)

# --- a fight ---

mutate(LUA,
       "\tEach(self.body, \"SetDesaturated\", on)\n",
       "",
       "look-gearworks: the housing keeps its brass in a fight",
       expect="in a fight the housing keeps its colour", script=S)

mutate(LUA,
       "self.glyph,\n\t\tself.gearbox }\n",
       "self.glyph }\n",
       "look-gearworks: the gearbox keeps its brass in a fight",
       expect="the gearbox or a cog keeps its colour", script=S)

# --- the words' room ---

mutate(LUA,
       "\tlocal textX = showIcon and math.ceil(gz + TEXT_GAP) or math.ceil(PLATE_AT * su) + BARE_GAP\n",
       "\tlocal textX = showIcon and math.ceil(gz - TEXT_GAP) or math.ceil(PLATE_AT * su) + BARE_GAP\n",
       "look-gearworks: the words start under the gauge",
       expect="the words start at", script=S)

mutate(LUA,
       "local GAUGE_MAX = 1.27\n",
       "local GAUGE_MAX = 1.6\n",
       "look-gearworks: a gauge half as tall again as the panel",
       expect="the gauge is", script=S)

mutate(LUA,
       "\tlocal boxed = W - textX - boxW >= GEAR_ROOM\n",
       "\tlocal boxed = true\n",
       "look-gearworks: the gearbox kept on a prompt with no room for words",
       expect="the gearbox leaves the words", script=S)

mutate(LUA,
       "\t\tt:SetShown(boxed)\n\t\tself.cogLights[i]:SetShown(boxed)\n",
       "\t\tt:SetShown(true)\n\t\tself.cogLights[i]:SetShown(boxed)\n",
       "look-gearworks: cogs drawn in the air past a plain end",
       expect="a cog is drawn with no gearbox", script=S)

mutate(LUA,
       "\tself.chipInset = boxed and math.ceil(boxW) + 4 or math.ceil(PLATE_AT * su) + 3\n",
       "\tself.chipInset = boxed and math.ceil(boxW * 0.5) + 4 or math.ceil(PLATE_AT * su) + 3\n",
       "look-gearworks: the tags laid over the gearbox",
       expect="the tags would lie over the gearbox", script=S)

# --- the Lua and the generator ---

mutate(GEN,
       "GEAR_M = 6.6           # the cogs' module",
       "GEAR_M = 6.2           # the cogs' module",
       "look-gearworks: the generator cuts the teeth to another module",
       expect="GEAR_M is 6.6 in the Lua and 6.2 in the generator", script=S)

mutate(GEN,
       "TEETH_A, TEETH_B, TEETH_C = 12, 8, 8\n",
       "TEETH_A, TEETH_B, TEETH_C = 12, 8, 6\n",
       "look-gearworks: the generator draws a cog with other teeth",
       expect="TEETH_A, TEETH_B, TEETH_C is", script=S)

mutate(GEN,
       "SEED_STEAM, SEED_SPARK, SEED_BUBBLE, SEED_STACK, SEED_PLANK = 6107, 6108, 6109, 6110, 6111\n",
       "SEED_STEAM, SEED_SPARK, SEED_BUBBLE, SEED_STACK, SEED_PLANK = 7107, 6108, 6109, 6110, 6111\n",
       "look-gearworks: the shipped steam is not the generator's",
       expect="does not match the file that ships", script=S)

# --- found by the review: one marker colour, Calm mid-breath, the second ring ---

mutate(LUA,
       "\tif mark ~= self.mark then\n\t\tself.mark = mark\n\t\tif not self.outcomeOn then self:SetNeedle(mark, true) end\n",
       "\tif mark ~= self.mark then\n\t\tself.mark = mark\n",
       "look-gearworks: the needle waits for a PaintReason that one marker colour never sends",
       expect="one marker colour: owed, the needle stands at", script=S)

mutate(LUA,
       "\t\t\tself:HoldPulse()\n\t\t\tPlayAll(self.calm)\n",
       "\t\t\tStopAll(self.pulse)\n\t\t\tPlayAll(self.calm)\n",
       "look-gearworks: Calm chosen mid-breath stops the lights and leaves the needle trembling",
       expect="Calm chosen mid-breath: the needle still trembles", script=S)

mutate(LUA,
       "\tself.skyward = { self.fx.rings[2].tex }\n",
       "\tself.skyward = {}\n",
       "look-gearworks: the second ring let out of the room with no word to hunt37",
       expect="the second ring is not named in skyward", script=S)

mutate(LUA,
       "\t\t\tlocal reach = math.min(textX - cx - kit.TEXT_MARGIN, gz / 2 + WAVE_PAST)\n",
       "\t\t\tlocal reach = gz / 2 + WAVE_PAST + 12\n",
       "look-gearworks: the second ring spread over the words",
       expect="the second ring reaches the words", script=S)

mutate(LUA,
       "\t\t\tgrow:SetScaleTo(to, to)\n",
       "\t\t\tgrow:SetScaleTo(from, from)\n",
       "look-gearworks: the second ring left on the icon's rim",
       expect="the second ring does not cross the dial", script=S)
