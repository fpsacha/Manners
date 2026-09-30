# Mutations for the Arcane look's readability: tests/scenarios/readable-arcane.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back something
# 1.5.0 did, or could, that the game draws harder to read than a preview
# render shows, and names the check that objects.

A = "Looks/Arcane.lua"
S = "runscenarios.py"

# --- the icon drawn clean ---------------------------------------------------

mutate(A, "\tself.ring:SetSize(iconSize / ICON_FRAME, iconSize / ICON_FRAME)\n",
       "\tself.ring:SetSize(iconSize, iconSize)\n",
       "Arcane's frame drawn over the icon's art",
       expect="Arcane draws the spell icon clean: drawn over the spell icon", script=S)

mutate(A, "\tfor _, t in ipairs({ self.track, self.drain, self.spark, self.check, self.wash }) do t:Hide() end\n",
       "\tfor _, t in ipairs({ self.track, self.drain, self.spark, self.wash }) do t:Hide() end\n",
       "Arcane's tick left on the icon at rest",
       expect="Arcane draws the spell icon clean: drawn over the spell icon", script=S)

mutate(A, "\tlocal from = showIcon and math.floor(cx + M / 2 + 0.5) or 0\n", "\tlocal from = 0\n",
       "Arcane's light crosses the icon",
       expect="Arcane's arrival leaves the icon clean after half a second", script=S)

# --- the count's coin -------------------------------------------------------

mutate(A, "\t\tself.badgeBox:SetPoint(\"RIGHT\", kit.textLayer, \"RIGHT\", -right, 0)\n",
       "\t\tself.badgeBox:SetPoint(\"CENTER\", kit.textLayer, \"LEFT\", self.cx + self.iconSize * 0.3,"
       " -self.iconSize * 0.3)\n",
       "Arcane's count coin back on the lens",
       expect="Arcane's count coin never covers the icon: the count's coin", script=S)

# --- the text's ground ------------------------------------------------------

mutate(A, "local SMOKE = 1\n", "local SMOKE = 0\n",
       "Arcane's glass without its smoke",
       expect="Arcane's text has a dark ground:", script=S)

mutate(A, "\tSliceColor(self.smoke, 0, 0, 0, kit.ink.light and self.smokeAlpha or 0)\n", "",
       "Arcane's smoke never laid",
       expect="Arcane's text has a dark ground:", script=S)

mutate(A, "\tself.wash:SetSize(M + 10, M + 10)\n", "\tself.wash:SetSize(M * 4, M * 4)\n",
       "Arcane's wash under the verdict",
       expect="Arcane's verdict reads on its wash:", script=S)

mutate(A, "\t\tself.wash:SetShown(self.showIcon)\n", "\t\tself.wash:Show()\n",
       "Arcane's wash under the verdict with the icon off",
       expect="Arcane's verdict reads on its wash:", script=S)

mutate(A, "\t\tself.checkAnim:Play()\n\tend\nend\n",
       "\t\tself.checkAnim:Play()\n\tend\n\tself:Shine(1, 1, 1, 0.45)\nend\n",
       "Arcane's landed buff shines across the verdict",
       expect="Arcane's verdict reads on its wash:", script=S)

# --- the name ---------------------------------------------------------------

mutate(A, "\t\tself:Whiten(fs)\n", "",
       "Arcane's preview name left gold",
       expect="Arcane's preview name is white: the preview's name is still gold", script=S)

# --- the text in a fight ------------------------------------------------------

mutate(A, "local FIGHT_LEAST = 4.5 / (COMBAT.text * COMBAT.text)\n", "local FIGHT_LEAST = 4.5\n",
       "Arcane's reason line dimmed below 4.5:1 in a fight",
       expect="Arcane's text has a dark ground:", script=S)

mutate(A, "\tif not self.outcome then self:Retint() end\n", "",
       "Arcane's reason line not brought up when a fight starts",
       expect="Arcane's reason line reads as a fight starts: the marker colour's reason line", script=S)

mutate(A, "kit.Legible(o[1], o[2], o[3], self.combat and FIGHT_LEAST or 4.5)",
       "kit.Legible(o[1], o[2], o[3], 4.5)",
       "Arcane's verdict dimmed below 4.5:1 in a fight",
       expect="Arcane's verdict reads on its wash:", script=S)
