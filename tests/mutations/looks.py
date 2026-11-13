# Mutations for the looks: tests/scenarios/looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake a
# look of its own could plausibly make -- in its file, or in the places
# Prompt.lua hands over to it -- and names the check that has to object.

# --- switching looks ------------------------------------------------------

# The glass look's regions left up under a look of its own.
mutate("Prompt/Panel.lua",
       "\tfor _, part in ipairs(self.builtinParts) do part:Hide() end\n",
       "",
       "glass regions left under a look of its own",
       expect="still shows under",
       script="runscenarios.py")

# Glass's frames of light never put back after a look of its own hid them.
mutate("Prompt/Panel.lua",
       "\tR.glowFrame:Show()\n",
       "",
       "glass's light left hidden after a look of its own",
       expect="a glass frame of light stayed hidden after a look of its own",
       script="runscenarios.py")

# The button's square highlight never put back.
mutate("Prompt/Panel.lua",
       "\tR.fx:SetShown(true)\n"
       "\tlocal hl = R.button:GetHighlightTexture()\n"
       "\tif hl then hl:SetVertexColor(1, 1, 1, 0.03) end\n",
       "\tR.fx:SetShown(true)\n",
       "the highlight left off after a look of its own",
       expect="the button's highlight stayed off after a look of its own",
       script="runscenarios.py")

# The old look never told to go.
mutate("Prompt/Panel.lua",
       "\tif S.activeLook and S.activeLook ~= look then S.activeLook:Hide() end\n",
       "",
       "a look never hidden when another is picked",
       expect="still shows after switching to",
       script="runscenarios.py")

# --- the reason -----------------------------------------------------------

# A class colour as it is, on a look that asks for it softened.
mutate("Prompt/Paint.lua",
       "\tlocal soften = S.activeLook and S.activeLook.classSoften\n",
       "\tlocal soften = nil\n",
       "class colours not softened on a look that asks",
       expect="in the full class colour on Leather",
       script="runscenarios.py")

# --- motion ---------------------------------------------------------------

# The cursor forgotten.
mutate("Prompt/Button.lua",
       "\t\tif S.activeLook then S.activeLook:Hover(true) end\n",
       "",
       "a look never told the cursor arrived",
       expect="the cursor on the panel did not light it",
       script="runscenarios.py")

# --- the fight ------------------------------------------------------------

# The whole of art dimmed, card and all, as the glass look does.
mutate("Prompt/Effects.lua",
       "\tR.art:SetAlpha(combatHeld and CombatRestAlpha() or 1)\n",
       "\tR.art:SetAlpha(combatHeld and 0.55 or 1)\n",
       "art dimmed whole under a look of its own in a fight",
       expect="art dimmed whole in a fight",
       script="runscenarios.py")

# The look never told about the fight.
mutate("Prompt/Effects.lua",
       "\tif S.activeLook then S.activeLook:Combat(on) end\n",
       "",
       "a look never told a fight started",
       expect="the icon keeps its colour in a fight",
       script="runscenarios.py")

# --- the lines, the chip, the list ----------------------------------------

# The glass look's list painted under a look's own.
mutate("Prompt/List.lua",
       "\t\t\tR.queueBars[i]:SetShown(not S.activeLook)\n",
       "\t\t\tR.queueBars[i]:Show()\n",
       "glass list bars under a look of its own",
       expect="the glass look's list bars show under Leather",
       script="runscenarios.py")

# --- the registry and the default -----------------------------------------

# A look from Looks/ the default again (1.5.0's mistake).
mutate("Core.lua",
       "\t\t\tstyle = \"glass\",\n",
       "\t\t\tstyle = \"leather\",\n",
       "the default look not Glass",
       expect="the default look is",
       script="runscenarios.py")

# A saved look nobody wrote the whitelist for, reset at login.
mutate("Core.lua",
       "\toneOf(p, \"style\", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)\n",
       "\toneOf(p, \"style\", { glass = true, minimal = true, leather = true },"
       " ns.defaults.profile.prompt.style)\n",
       "a stub look reset at login",
       expect="a saved Ribbon look was reset",
       script="runscenarios.py")

# A stub that draws nothing instead of the look it names.
mutate("Looks/Looks.lua",
       "\tif look and look.fallback then look = Looks.list[look.fallback] end\n",
       "",
       "a stub look draws nothing",
       expect="a look not written yet does not draw as the look it names",
       script="runscenarios.py")

# --- the review's findings (round 16) -------------------------------------

# Glass's pulse left looping, hidden, under a look of its own.
mutate("Prompt/Panel.lua",
       "\t\tif f.pulse then f.pulse:Stop() end\n",
       "",
       "glass's pulse loops on under a look of its own",
       expect="glass's pulse still loops under Leather",
       script="runscenarios.py")

# FitLine keeping no width for the looks, on the repaint of a line it has the
# answer for (the measured width is part of that answer).
mutate("Prompt/Text.lua",
       "\t\tfit.drawn[fs] = memo.width\n",
       "\t\tfit.drawn[fs] = nil\n",
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
