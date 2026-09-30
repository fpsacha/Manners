# Mutations for the looks: tests/scenarios/looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake a
# look of its own could plausibly make -- in its file, or in the places
# Prompt.lua hands over to it -- and names the check that has to object.

# --- switching looks ------------------------------------------------------

# The glass look's regions left up under Luxe.
mutate("Prompt.lua",
       "\tfor _, part in ipairs(self.builtinParts) do part:Hide() end\n",
       "",
       "glass regions left under a look of its own",
       expect="still shows under",
       script="runscenarios.py")

# Glass's frames of light never put back after Luxe hid them.
mutate("Prompt.lua",
       "\tglowFrame:Show()\n",
       "",
       "glass's light left hidden after Luxe",
       expect="a glass frame of light stayed hidden after Luxe",
       script="runscenarios.py")

# The button's square highlight never put back.
mutate("Prompt.lua",
       "\tshineFrame:Show()\n\tlocal hl = button:GetHighlightTexture()\n"
       "\tif hl then hl:SetVertexColor(1, 1, 1, 0.045) end\n",
       "\tshineFrame:Show()\n",
       "the highlight left off after Luxe",
       expect="the button's highlight stayed off after Luxe",
       script="runscenarios.py")

# Luxe's mask left on the icon.
mutate("Looks/Luxe.lua",
       "\t\ticon:RemoveMaskTexture(self.mask)\n",
       "",
       "Luxe's mask left on the icon",
       expect="Luxe's mask still shapes the icon",
       script="runscenarios.py")

# The reason line left inside Luxe's tag.
mutate("Looks/Luxe.lua",
       "\t\tkit.sub:SetParent(kit.textLayer)\n",
       "",
       "the reason line left in Luxe's tag",
       expect="the reason line is still inside Luxe's tag",
       script="runscenarios.py")

# textLayer left raised.
mutate("Looks/Luxe.lua",
       "\tkit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + 1)\n",
       "",
       "textLayer left at Luxe's level",
       expect="textLayer kept Luxe's frame level",
       script="runscenarios.py")

# The old look never told to go.
mutate("Prompt.lua",
       "\tif activeLook and activeLook ~= look then activeLook:Hide() end\n",
       "",
       "a look never hidden when another is picked",
       expect="still shows after switching to",
       script="runscenarios.py")

# --- the reason -----------------------------------------------------------

# The ring left out of the reason's colour.
mutate("Looks/Luxe.lua",
       "\tself.ring:SetVertexColor(r, g, b, 0.85)\n",
       "\tself.ring:SetVertexColor(1, 1, 1, 0.85)\n",
       "Luxe's ring not in the reason colour",
       expect="the ring round the icon is not in",
       script="runscenarios.py")

# The marker switched off and the spine still coloured.
mutate("Looks/Luxe.lua",
       "\tif mode == \"off\" then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n",
       "",
       "Luxe ignores the marker switched off",
       expect="with the marker off the spine still carries",
       script="runscenarios.py")

# "Stripe" taken to mean the ring as well.
mutate("Looks/Luxe.lua",
       "\tself:Tint(r, g, b, mode == \"icon\" or mode == \"both\")\n",
       "\tself:Tint(r, g, b, true)\n",
       "Luxe's ring kept on the stripe-only marker",
       expect="with the marker on the stripe only",
       script="runscenarios.py")

# A class colour as it is, on Luxe.
mutate("Prompt.lua",
       "\tlocal soften = activeLook and activeLook.classSoften\n",
       "\tlocal soften = nil\n",
       "class colours not softened on Luxe",
       expect="in the full class colour on Luxe",
       script="runscenarios.py")

# One height for two lines, whatever the look.
mutate("Prompt.lua",
       "\tif look and look.TwoLineHeight then return look.TwoLineHeight(fontSize) end\n",
       "",
       "the two-line height not the look's own",
       expect="two lines need",
       script="runscenarios.py")

# --- motion ---------------------------------------------------------------

# The owed pulse looping on Calm.
mutate("Looks/Luxe.lua",
       "\t\tif full then\n\t\t\tif not self.pulseAnim:IsPlaying() then self.pulseAnim:Play() end\n",
       "\t\tif true then\n\t\t\tif not self.pulseAnim:IsPlaying() then self.pulseAnim:Play() end\n",
       "Luxe's pulse loops on Calm",
       expect="loop on Calm with somebody owed on top",
       script="runscenarios.py")

# The pulse never stopped once nobody owed is on top.
mutate("Looks/Luxe.lua",
       "function Luxe:StopAttention()\n\tself.pulseAnim:Stop()\n",
       "function Luxe:StopAttention()\n",
       "Luxe's pulse outlives the favour",
       expect="the owed pulse kept going with nobody owed on top",
       script="runscenarios.py")

# The cursor forgotten.
mutate("Prompt.lua",
       "\t\tif activeLook then activeLook:Hover(true) end\n",
       "",
       "Luxe never told the cursor arrived",
       expect="the cursor on the panel did not light it",
       script="runscenarios.py")

# A sent cast flourished like a landed one.
mutate("Looks/Luxe.lua",
       "\tif kind == \"cast\" then self:Sheen(1, 1, 1, 0.40) end\n",
       "\tif kind == \"cast\" or kind == \"sent\" then self:Sheen(1, 1, 1, 0.40) end\n",
       "Luxe's light on an unconfirmed cast",
       expect="a cast nobody confirmed got Luxe's flourish",
       script="runscenarios.py")

# --- the fight ------------------------------------------------------------

# The whole of art dimmed, card and all, as the glass look does.
mutate("Prompt.lua",
       "\tart:SetAlpha(combatHeld and (activeLook and activeLook.combatArtAlpha or 0.55) or 1)\n",
       "\tart:SetAlpha(combatHeld and 0.55 or 1)\n",
       "art dimmed whole on Luxe in a fight",
       expect="art dimmed whole in a fight",
       script="runscenarios.py")

# The look never told about the fight.
mutate("Prompt.lua",
       "\tif activeLook then activeLook:Combat(on) end\n",
       "",
       "Luxe never told a fight started",
       expect="the icon keeps its colour in a fight",
       script="runscenarios.py")

# The icon left grey after the fight.
mutate("Looks/Luxe.lua",
       "\tself.kit.icon:SetDesaturated(self.combat and true or false)\n",
       "",
       "the icon left grey after a refusal",
       expect="the icon stayed grey after the refusal ran out",
       script="runscenarios.py")

# The spine dimmed with the ink.
mutate("Looks/Luxe.lua",
       "\tfor _, t in ipairs({ self.shade, self.rim, kit.icon }) do t:SetAlpha(ink) end\n",
       "\tfor _, t in ipairs({ self.shade, self.rim, kit.icon, self.spine }) do t:SetAlpha(ink) end\n",
       "Luxe's spine dims in a fight",
       expect="the spine lost the reason's colour in a fight",
       script="runscenarios.py")

# --- outcomes -------------------------------------------------------------

# The verdict written over the name, as the glass look writes it.
mutate("Looks/Luxe.lua",
       "\t\tkit.SetLine(kit.name, who)\n",
       "\t\tkit.SetLine(kit.name, lead)\n",
       "Luxe's outcome moves the name",
       expect="a landed buff moved the name",
       script="runscenarios.py")

# The English verdict on every client.
mutate("Looks/Luxe.lua",
       "\treturn locale == \"enUS\" or locale == \"enGB\" or rawget(L, english) ~= nil\n",
       "\treturn true\n",
       "English verdicts on a German client",
       expect="a German client's tag reads the English",
       script="runscenarios.py")

# The glyph kept after the verdict is gone.
mutate("Looks/Luxe.lua",
       "\tlocal glyph = self.glyphOn and self:ShowsVerdict()\n",
       "\tlocal glyph = self.glyphOn\n",
       "Luxe's tick outlives the verdict",
       expect="the verdict stayed on the tag",
       script="runscenarios.py")

# A refusal that leaves the icon in colour.
mutate("Looks/Luxe.lua",
       "\tkit.icon:SetDesaturated(kind == \"failed\" or self.combat or false)\n",
       "",
       "a refusal on Luxe leaves the icon in colour",
       expect="a refusal did not grey the icon",
       script="runscenarios.py")

# --- the lines, the chip, the list ----------------------------------------

# The name cut to keep the chip.
mutate("Looks/Luxe.lua",
       "\t\t\tif width * least / size > self.W - self.textX - fit.chipRoom + 0.5 then on = false end\n",
       "",
       "Luxe's chip cuts a long name",
       expect="the count chip stayed up and cut a name",
       script="runscenarios.py")

# The list hung below whichever side has the room.
mutate("Looks/Luxe.lua",
       "\t\t\ty = 3 + height - 4 - (i - 1) * pitch - pitch / 2\n\t\t\tedge = \"TOPLEFT\"\n",
       "\t\t\ty = -(3 + 4 + (i - 1) * pitch + pitch / 2)\n\t\t\tedge = \"BOTTOMLEFT\"\n",
       "Luxe's list never hangs above",
       expect="the list above the panel is not hung over it",
       script="runscenarios.py")

# The glass look's list painted under Luxe's.
mutate("Prompt.lua",
       "\t\t\tqueueBars[i]:SetShown(not activeLook)\n",
       "\t\t\tqueueBars[i]:Show()\n",
       "glass list bars under Luxe",
       expect="the glass look's list bars show under Luxe",
       script="runscenarios.py")

# The tag kept up with the second line off.
mutate("Looks/Luxe.lua",
       "\tif not (kit.fit.twoLine and fs:IsShown() and type(text) == \"string\" and text ~= \"\") then\n",
       "\tif not (type(text) == \"string\" and text ~= \"\") then\n",
       "Luxe's tag up with one line",
       expect="the second line switched off and the tag is still up",
       script="runscenarios.py")

# The round icon kept square.
mutate("Looks/Luxe.lua",
       "\tlocal maskFile = ART .. (round and \"IconMaskRound\" or \"IconMask\")\n",
       "\tlocal maskFile = ART .. \"IconMask\"\n",
       "Luxe ignores the round icon",
       expect="the round icon kept the square mask",
       script="runscenarios.py")

# --- the registry and the default -----------------------------------------

# Glass the default again.
mutate("Core.lua",
       "\t\t\tstyle = \"luxe\",\n",
       "\t\t\tstyle = \"glass\",\n",
       "the default look not Luxe",
       expect="the default look is",
       script="runscenarios.py")

# A saved look nobody wrote the whitelist for, reset at login.
mutate("Core.lua",
       "\toneOf(p, \"style\", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)\n",
       "\toneOf(p, \"style\", { glass = true, framed = true, minimal = true, luxe = true },"
       " ns.defaults.profile.prompt.style)\n",
       "a stub look reset at login",
       expect="a saved Toast look was reset",
       script="runscenarios.py")

# A stub that draws nothing instead of Luxe.
mutate("Looks/Looks.lua",
       "\tif look and look.fallback then look = Looks.list[look.fallback] end\n",
       "",
       "a stub look draws nothing",
       expect="a look not written yet does not draw as Luxe",
       script="runscenarios.py")
