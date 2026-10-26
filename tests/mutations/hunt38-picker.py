# Mutations for hunt 38, the picker and the switching between looks:
# tests/scenarios/hunt38-picker.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# switching, the saved styles or the options page could plausibly make, and
# names the scenario that objects.

S = "runscenarios.py"

# --- Round the icon off ----------------------------------------------------

# The one fault the hunt found: the switch was greyed out for the Letter's seal
# and live on the Toast's and the Ribbon's medallions, which are round whatever
# it says.
mutate("Looks/Looks.lua",
       "Looks.roundAlways = { toast = true, ribbon = true, letter = true }\n",
       "Looks.roundAlways = { letter = true }\n",
       "hunt38-picker: Round the icon off live on the medallions",
       expect="hunt38-picker: Round the icon off is greyed out", script=S)

# A look that reads the switch greyed out with the others.
mutate("Looks/Looks.lua",
       "Looks.roundAlways = { toast = true, ribbon = true, letter = true }\n",
       "Looks.roundAlways = { toast = true, ribbon = true, letter = true, leather = true }\n",
       "hunt38-picker: Round the icon off greyed out on a look that reads it",
       expect="hunt38-picker: Round the icon off is greyed out", script=S)

# --- switching -------------------------------------------------------------

# The look going away asked to put back what it borrowed.
mutate("Prompt/Panel.lua",
       "\tif S.activeLook and S.activeLook ~= look then S.activeLook:Hide() end\n",
       "",
       "hunt38-picker: the look put away is never told to hide",
       expect="hunt38-picker: switching", script=S)

# Luxe's hand-back of textLayer's frame level.
mutate("Looks/Luxe.lua",
       "\tkit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)\n\tkit.textLayer:SetAlpha(1)\n",
       "\tkit.textLayer:SetAlpha(1)\n",
       "hunt38-picker: Luxe keeps its frame level on the text layer",
       expect="hunt38-picker: switching", script=S)

# The built-in looks' frames of light left hidden after a look from Looks/.
mutate("Prompt/Panel.lua",
       "\tR.glowFrame:Show()\n\tR.rimFrame:Show()\n",
       "\tR.rimFrame:Show()\n",
       "hunt38-picker: the glass's glow frame stays hidden after another look",
       expect="hunt38-picker: switching", script=S)

# Luxe's room for the reason line, which it keeps in Prompt's own table.
mutate("Looks/Luxe.lua",
       "\tkit.fit.room[kit.sub] = nil\n\tself.combat, self.hovered,",
       "\tself.combat, self.hovered,",
       "hunt38-picker: Luxe leaves its room for the reason line in Prompt's table",
       expect="hunt38-picker: switching", script=S)

# --- a fight ---------------------------------------------------------------

# A restyle in a fight forgotten instead of waiting for its end.
mutate("Prompt/Panel.lua",
       "\tif InCombatLockdown() then\n\t\tself.pendingStyle = true\n\t\treturn\n\tend\n",
       "\tif InCombatLockdown() then\n\t\treturn\n\tend\n",
       "hunt38-picker: a look picked in a fight is forgotten",
       expect="hunt38-picker: a look picked in a fight", script=S)

# --- the cards -------------------------------------------------------------

# Every click picks the first look.
mutate("Options/Window/WidgetsTheme.lua",
       "\tW.Apply(row, card.key)\n",
       "\tW.Apply(row, row.cards[1].key)\n",
       "hunt38-picker: every card picks the first look",
       expect="hunt38-picker: clicking every card", script=S)

# --- saved styles ----------------------------------------------------------

# A style nobody knows kept as it is.
mutate("Core.lua",
       "\toneOf(p, \"style\", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)\n",
       "",
       "hunt38-picker: a style no look has is kept",
       expect="hunt38-picker: a style no look has", script=S)

# One look left out of the styles that may be saved: its players start on glass
# at the next login.
mutate("Looks/Looks.lua",
       "\tfor key in pairs(Looks.list) do out[key] = true end\n",
       "\tfor key in pairs(Looks.list) do out[key] = key ~= \"leather\" or nil end\n",
       "hunt38-picker: the leather style is not one that may be saved",
       expect="hunt38-picker: every look's style goes out in a string", script=S)

# A profile switched to keeps the look of the one left.
mutate("Core.lua",
       "\tns.Guard(\"ApplyStyle on profile change\", ns.Prompt.ApplyStyle, ns.Prompt)\n",
       "",
       "hunt38-picker: a profile switch does not restyle the prompt",
       expect="hunt38-picker: switching profile", script=S)
