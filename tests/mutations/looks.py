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
       "\tif kind == \"cast\" then\n\t\tlocal o = OUTCOME.cast\n",
       "\tif kind == \"cast\" or kind == \"sent\" then\n\t\tlocal o = OUTCOME.cast\n",
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
       "\tkit.SetLine(kit.name, stays and who or lead)\n",
       "\tkit.SetLine(kit.name, lead)\n",
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
       "\tlocal glyph = self.glyphOn and verdict\n",
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
       "\t\t\tif width * least / size > self.W - self.textX - fit.chipRoom - 0.5 then on = false end\n",
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
       "\tlocal shown = fit.twoLine and fs:IsShown() and (secret or",
       "\tlocal shown = (secret or",
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

# --- the review's findings (round 16) -------------------------------------

# The spine left level with the frames of light, which then draw over it.
mutate("Looks/Luxe.lua",
       "\tself.spineFrame:SetFrameLevel(base + 2)\n",
       "",
       "Luxe's light drawn over the spine",
       expect="a frame of light is drawn over the spine",
       script="runscenarios.py")

# Class colours only half softened: a mage's name lands on the target colour.
mutate("Looks/Luxe.lua",
       "\tclassSoften = 0.85,\n",
       "\tclassSoften = 0.55,\n",
       "Luxe's class colours half softened",
       expect="more than a tint on white",
       script="runscenarios.py")

# The name kept on one line, where no tag says the verdict.
mutate("Looks/Luxe.lua",
       "\tlocal stays = tag and who and word\n",
       "\tlocal stays = who and word\n",
       "Luxe's one-line outcome without its verdict",
       expect="one line does not say so",
       script="runscenarios.py")

# A verdict too long for the tag drawn cut in it.
mutate("Looks/Luxe.lua",
       "\tif width > room + 0.5 then\n",
       "\tif false then\n",
       "Luxe's tag ends in an ellipsis",
       expect="drawn cut in it",
       script="runscenarios.py")

# The dropped verdict never said on the name line.
mutate("Looks/Luxe.lua",
       "\t\tif stays and (dropped or self.dropped) then kit.SetLine(kit.name, lead) end\n",
       "",
       "Luxe's dropped verdict said nowhere",
       expect="left the name line without it",
       script="runscenarios.py")

# The tag's room left behind for the built-in looks.
mutate("Looks/Luxe.lua",
       "\tkit.fit.room[kit.sub] = nil\n",
       "",
       "Luxe's reason-line room left after a switch",
       expect="kept Luxe's room after switching",
       script="runscenarios.py")

# The chip at the two-line name's height on one line.
mutate("Looks/Luxe.lua",
       "\tself.chipBox:SetPoint(\"RIGHT\", kit.textLayer, \"RIGHT\", -8, twoLine and self.nameY or 0)\n",
       "\tself.chipBox:SetPoint(\"RIGHT\", kit.textLayer, \"RIGHT\", -8, self.nameY)\n",
       "Luxe's chip off the one-line name",
       expect="on one line the count chip",
       script="runscenarios.py")

# Luxe's own two-line height, above glass's: a moved profile loses a line.
mutate("Looks/Luxe.lua",
       "\treturn math.max(ns.TwoLineHeight(fontSize, \"glass\"), BlockHeight(fontSize, true))\n",
       "\treturn BlockHeight(fontSize)\n",
       "Luxe needs more height than glass for two lines",
       expect="lost the reason line on Luxe",
       script="runscenarios.py")

# Two lines allowed at glass's height, with the tag never drawn tight.
mutate("Looks/Luxe.lua",
       "\tlocal tight = H < BlockHeight(fs)\n",
       "\tlocal tight = false\n",
       "Luxe's tag never tight",
       expect="the tag runs off the card",
       script="runscenarios.py")

# Glass's pulse left looping, hidden, under Luxe.
mutate("Prompt.lua",
       "\t\tif f.pulse then f.pulse:Stop() end\n",
       "",
       "glass's pulse loops on under Luxe",
       expect="glass's pulse still loops under Luxe",
       script="runscenarios.py")

# "Both" drawn the same as "icon".
mutate("Looks/Luxe.lua",
       "\tSliceShown(self.edge, self.both)\n",
       "",
       "Luxe's \"both\" does nothing",
       expect="does not light the card's top edge",
       script="runscenarios.py")

# A line's own colour ignored: red words in a gold tag.
mutate("Looks/Luxe.lua",
       "\tlocal c = self.pillCode or self.tint or NEUTRAL\n",
       "\tlocal c = self.tint or NEUTRAL\n",
       "Luxe's tag ignores the line's colour",
       expect="sits in a tag of another colour",
       script="runscenarios.py")

# The fight's grey words given a grey tag.
mutate("Looks/Luxe.lua",
       "\tlocal hex = shown and not secret and not combat and not verdict",
       "\tlocal hex = shown and not secret and not verdict",
       "Luxe's tag loses the reason in a fight",
       expect="in a fight the tag lost the reason's colour",
       script="runscenarios.py")

# The fight's dim on textLayer again, where the cross-fade overrides it.
mutate("Looks/Luxe.lua",
       "\tkit.name:SetAlpha(text)\n",
       "\tkit.textLayer:SetAlpha(text)\n",
       "Luxe dims textLayer in a fight",
       expect="the lines are not dimmed in a fight",
       script="runscenarios.py")

# The lines left dim when another look takes over mid-fight.
mutate("Looks/Luxe.lua",
       "\tfor _, fs in ipairs({ kit.name, kit.sub, kit.count }) do fs:SetAlpha(1) end\n",
       "",
       "Luxe's fight dim left on the lines",
       expect="the fight's dim stayed on the lines after switching",
       script="runscenarios.py")

# The khaki wash over a sent cast.
mutate("Looks/Luxe.lua",
       "\t\tif kind == \"sent\" then\n\t\t\tself.resultFrame:SetAlpha(0)\n",
       "\t\tif false then\n\t\t\tself.resultFrame:SetAlpha(0)\n",
       "Luxe washes a sent cast",
       expect="a cast nobody confirmed washed the card",
       script="runscenarios.py")

# A nearly clear panel treated as the card.
mutate("Looks/Luxe.lua",
       "\tself.clear = ba < 0.35\n",
       "\tself.clear = false\n",
       "Luxe's text bare on a clear panel",
       expect="is not outlined",
       script="runscenarios.py")

# The shadow drawn round nothing.
mutate("Looks/Luxe.lua",
       "\tif ba < 0.2 then SliceShown(self.shadow, false) end\n",
       "",
       "Luxe's shadow round a clear panel",
       expect="the shadow is drawn round a clear panel",
       script="runscenarios.py")

# The chip measuring the name again on every repaint.
mutate("Looks/Luxe.lua",
       "fit.drawn[name] or kit.TextWidth(name), fit.size[name]",
       "kit.TextWidth(name), fit.size[name]",
       "Luxe's chip measures on every repaint",
       expect="five repaints of the same panel measured",
       script="runscenarios.py")

# FitLine keeping no width for the looks.
mutate("Prompt.lua",
       "\tfit.drawn[fs] = w\n",
       "",
       "FitLine keeps no measured width",
       expect="five repaints of the same panel measured",
       script="runscenarios.py")

# The German translation without its verdict word: the new looks fall back to
# the built-in line, and the scenario that asks for the German word says so.
mutate("Locales/deDE.lua",
       "L[\"buffed\"] = \"gestärkt\"\n",
       "",
       "German verdict word missing",
       expect="says the verdict in German",
       script="runscenarios.py")
