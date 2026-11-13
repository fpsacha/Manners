# Mutations for what the default look wears (Looks/Glass.lua) and for the hooks
# Prompt/ calls it through. Caught by tests/scenarios/look-glass.lua.

S = "runscenarios.py"
GLASS = "Looks/Glass.lua"

# --- the gryphons and the rails ---

mutate(GLASS,
       "\t\t\t\tt:SetPoint(\"BOTTOMRIGHT\", art, \"BOTTOMLEFT\", reach, -GRYPHON_DROP)\n",
       "\t\t\t\tt:SetPoint(\"BOTTOMRIGHT\", art, \"BOTTOMLEFT\", G, -GRYPHON_DROP)\n",
       "look-glass: the left gryphon stood over the icon",
       expect="in over the pane", script=S)

mutate(GLASS,
       "local GRYPHON_OVER, GRYPHON_MIN, GRYPHON_MAX, GRYPHON_IN, GRYPHON_DROP = 18, 34, 140, 0.10, 3",
       "local GRYPHON_OVER, GRYPHON_MIN, GRYPHON_MAX, GRYPHON_IN, GRYPHON_DROP = 18, 34, 96, 0.10, 3",
       "look-glass: a tall pane's gryphons shorter than the pane",
       expect="tall at a pane", script=S)

mutate(GLASS,
       "\t\teye:SetPoint(\"CENTER\", self.gryphon[i], \"TOPLEFT\", G * (left and EYE_X or 1 - EYE_X), -G * EYE_Y)\n",
       "\t\teye:SetPoint(\"CENTER\", self.gryphon[i], \"TOPLEFT\", G * EYE_X, -G * EYE_Y)\n",
       "look-glass: the right gryphon's eye on the back of its head",
       expect="gryphon 2's eye is at", script=S)

mutate(GLASS,
       "\t\tself.gryphon[i] = tex(frame, \"ARTWORK\", 1, \"Gryphon\" .. side)\n",
       "\t\tself.gryphon[i] = tex(frame, \"ARTWORK\", 1, \"GryphonL\")\n",
       "look-glass: the left gryphon at both ends",
       expect="the ends do not each have their own gryphon", script=S)

mutate(GLASS,
       "\tself.railBottom:SetTexCoord(0, tiles, 1, 0)\n",
       "\tself.railBottom:SetTexCoord(0, tiles, 0, 1)\n",
       "look-glass: the bottom rail lit from below",
       expect="the bottom rail is not the top one upside down", script=S)

mutate(GLASS,
       "\tlocal tiles = W / RAIL_TILE\n",
       "\tlocal tiles = 1\n",
       "look-glass: one tile of rail stretched along the pane",
       expect="a rail shows", script=S)

mutate(GLASS,
       "\tlocal gryphons = p.gryphons == true\n",
       "\tlocal gryphons = true\n",
       "look-glass: the gryphons' switch reads nothing",
       expect="a piece of gryphon", script=S)

mutate("Core.lua",
       "\t\t\tgryphons = false,\n",
       "\t\t\tgryphons = true,\n",
       "look-glass: the gryphons on for everybody who never asked",
       expect="as the look comes, a piece of gryphon", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return P().style ~= \"glass\" end,\n",
       "\t\t\t\tdisabled = function() return false end,\n",
       "look-glass: the gryphons' switch live on a look without them",
       expect="the switch is live on", script=S)

# --- put on and taken off ---

mutate("Prompt/Panel.lua",
       "\tif S.dress and S.dress ~= dress then S.dress:Hide() end\n",
       "",
       "look-glass: another look still wears the glass's gryphons",
       expect="a piece of Glass's is still drawn", script=S)

mutate("Prompt/Panel.lua",
       "\tlocal dress = not look and ns.Looks.Dress(style) or nil\n",
       "\tlocal dress = ns.Looks.Dress(\"glass\")\n",
       "look-glass: every look dressed as the glass",
       expect="still wears the glass's dressing", script=S)

mutate(GLASS,
       "\tself.flow:StopAll()\n\tfor _, g in ipairs(self.anims) do g:Stop() end\n",
       "\tfor _, g in ipairs(self.anims) do g:Stop() end\n",
       "look-glass: the clock runs on under another look",
       expect="Glass's clock still runs", script=S)

# --- the light at rest ---

mutate(GLASS,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
       "look-glass: the light drifts on Calm",
       expect="on Calm", script=S)

mutate(GLASS,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "look-glass: the light drifts in a fight",
       expect="in a fight", script=S)

mutate(GLASS,
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
       "\tlocal on = (self.active and not self.combat and self.kit.FullEffects()) and true or false\n",
       "look-glass: the clock runs with the prompt down",
       expect="with the prompt down", script=S)

mutate(GLASS,
       "local CAUSTIC_SPEEDS = { { 0.021, 0.008 }, { -0.013, 0.012 } }",
       "local CAUSTIC_SPEEDS = { { 0.021, 0.008 }, { 0.013, 0.012 } }",
       "look-glass: the two sheets of light drift as one",
       expect="the two sheets of light drift the same way", script=S)

mutate(GLASS,
       "\t\tself.causticFlow[i]:Window(cw / CAUSTIC_W, ch / CAUSTIC_H)\n",
       "",
       "look-glass: the light stretched over a wider pane",
       expect="the light shows", script=S)

mutate(GLASS,
       "\tlocal k = self.combat and COMBAT_GILT or 1\n",
       "\tlocal k = 1\n",
       "look-glass: the gilt as bright in a fight",
       expect="in a fight the gilt is at", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:Combat(on) end\n",
       "",
       "look-glass: the dressing never told of the fight",
       expect="in a fight", script=S)

mutate("Prompt/Paint.lua",
       "\tif S.dress and S.dress.Painted then S.dress:Painted(entry) end\n",
       "",
       "look-glass: the light never comes back once the prompt has been down",
       expect="the light does not come back", script=S)

# --- the ready border ---

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:Attention(isNew, arrived and not self:OutcomeLive(), mode) end\n",
       "",
       "look-glass: nobody owed ever lights the border",
       expect="with Anna owed the border is not up", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.activeLook then S.activeLook:StopAttention() end\n\tif S.dress then S.dress:StopAttention() end\n",
       "\tif S.activeLook then S.activeLook:StopAttention() end\n",
       "look-glass: the border left up with nobody owed",
       expect="nobody owed any more, and the border is still up", script=S)

mutate(GLASS,
       "\t\tself.antFlow[i] = flow:Scroll(self.ants[i], -ANT_SPEED, 0, 1, 1, i - 1)\n",
       "\t\tself.antFlow[i] = flow:Scroll(self.ants[i], -ANT_SPEED, 0, 1, 1, 0)\n",
       "look-glass: every side of the border laid along the top",
       expect="quarter turns", script=S)

mutate(GLASS,
       "\t\tself.antFlow[i] = flow:Scroll(self.ants[i], -ANT_SPEED, 0, 1, 1, i - 1)\n",
       "\t\tself.antFlow[i] = flow:Scroll(self.ants[i], ANT_SPEED, 0, 1, 1, i - 1)\n",
       "look-glass: the dash runs tail first",
       expect="dash runs backwards", script=S)

mutate(GLASS,
       "\t\t\tself.antFlow[i]:Phase(-(i - 1) * span, 0)\n",
       "",
       "look-glass: the dash jumps at each corner",
       expect="of a tile after side", script=S)

mutate(GLASS,
       "\t\t\tif full and flashStyle == \"pulse\" then\n\t\t\t\tif not self.antFlow[i]:IsPlaying() then self.antFlow[i]:Play() end\n",
       "\t\t\tif flashStyle == \"pulse\" then\n\t\t\t\tif not self.antFlow[i]:IsPlaying() then self.antFlow[i]:Play() end\n",
       "look-glass: the border runs on Calm",
       expect="on Calm side", script=S)

mutate(GLASS,
       "\tself.bloom:SetVertexColor(r, g, b, 1)\n",
       "\tself.bloom:SetVertexColor(1, 1, 1, 1)\n",
       "look-glass: the bloom white whatever the reason",
       expect="the bloom is not in the owed colour", script=S)

mutate(GLASS,
       "\t\tself.antsFrame:Hide()\n\t\tself.star:Hide()\n",
       "\t\tself.star:Hide()\n",
       "look-glass: the border drawn with the icon off",
       expect="with the icon off the border is drawn round nothing", script=S)

mutate(GLASS,
       "\tfor i = 1, 2 do\n\t\tself.eyeGlint[i]:Stop()\n",
       "\tfor i = 1, 2 do\n",
       "look-glass: the eyes glint as at rest while somebody is owed",
       expect="glints as at rest with somebody owed", script=S)

# --- the gilt catching the light ---

mutate(GLASS,
       "\tif arrived and full then self:Catch(CATCH_FAVOUR) end\n",
       "",
       "look-glass: a favour done lights nothing",
       expect="a favour just done did not catch the gilt", script=S)

mutate("Prompt/Effects.lua",
       "\tif S.dress then S.dress:Flourish(kind) end\n",
       "",
       "look-glass: a landing never reaches the dressing",
       expect="a landing did not wink the star", script=S)

mutate(GLASS,
       "\tif kind ~= \"cast\" then return end\n\tself:Catch(CATCH_LAND)\n",
       "\tself:Catch(CATCH_LAND)\n",
       "look-glass: a refusal winks the star",
       expect="a refusal winks the star", script=S)

mutate(GLASS,
       "\tif self.combat or not self.active then return end\n\tif kind ~= \"cast\" then return end\n",
       "\tif not self.active then return end\n\tif kind ~= \"cast\" then return end\n",
       "look-glass: the gilt flashes in a fight",
       expect="in a fight a landing still flashes the gilt", script=S)

mutate(GLASS,
       "local CATCH_FAVOUR, CATCH_LAND, CATCH_UP, CATCH_DOWN = 0.55, 0.9, 0.08, 0.42",
       "local CATCH_FAVOUR, CATCH_LAND, CATCH_UP, CATCH_DOWN = 0.55, 0.9, 0.08, 0.72",
       "look-glass: an additive flash held past its time",
       expect="flash lasts", script=S)

mutate(GLASS,
       "\tfor order, part in ipairs({ { STAR_UP, -20 }, { STAR_DOWN, -70 } }) do\n",
       "\tfor order, part in ipairs({ { STAR_UP + STAR_DOWN, -20 }, { STAR_DOWN, -70 } }) do\n",
       "look-glass: the star turns on after its light has gone",
       expect="the star lasts", script=S)

mutate(GLASS,
       "\tfor i, t in ipairs(list) do t:SetAlpha(held[i] or 1) end\n",
       "",
       "look-glass: a reason's colour brings the light in the glass up to full",
       expect="look-glass: a reason's colour leaves the light in the glass as faint", script=S)
