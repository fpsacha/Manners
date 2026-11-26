# Mutations for when the fight buttons show (Prompt/BreakFree.lua,
# Prompt/MendPet.lua, `prompt.fightButtons` in Core.lua, its place in the
# options window). Caught by tests/scenarios/fightbuttons.lua; each undoes one
# rule: out of sight until the need, no tooltip out of sight, a new fight at
# alpha 0, All fight keeping the dim buttons, the setting's default and repair.

S = "runscenarios.py"
BF = "Modules/Combat/BreakFree.lua"
MP = "Modules/Combat/MendPet.lua"
FB = "fightbuttons: "

# --- Will of the Forsaken out of sight until the need

mutate(BF,
       "\tlocal to = bright and 1 or (shown and (always and 0.35 or 0.6) or 0)\n",
       "\tlocal to = bright and 1 or (shown and (always and 0.35 or 0.6) or 0.35)\n",
       "fightbuttons: will of the forsaken dim for every fight again",
       expect=FB + "will of the forsaken is out of sight", script=S)

mutate(BF,
       "\t-- Out of sight: nothing to say.\n\tif fadeTo == 0 then return end\n",
       "\t-- Out of sight: nothing to say.\n",
       "fightbuttons: a tooltip for a button nobody can see",
       expect=FB + "will of the forsaken is out of sight", script=S)

mutate(BF,
       "\tbutton:SetAlpha(fadeTo)\n\tfader:Hide()\n\tsettledOn, dirty = true, false\nend",
       "\tsettledOn, dirty = true, false\nend",
       "fightbuttons: the fight's end leaves the last alpha on the button",
       expect=FB + "a new fight starts out of sight", script=S)

mutate(BF,
       "\t\t\tbutton:SetAlpha(fadeTo)\n\t\t\tfader:Hide()\n\t\tend\n\t\treturn\n",
       "\t\tend\n\t\treturn\n",
       "fightbuttons: the pull leaves the last alpha on the button",
       expect=FB + "a new fight starts out of sight", script=S)

mutate(BF,
       "\t\tif button then\n\t\t\tbutton:SetAlpha(fadeTo)\n\t\t\tfader:Hide()\n\t\tend\n\t\treturn\n",
       "\t\tbutton:SetAlpha(fadeTo)\n\t\tfader:Hide()\n\t\treturn\n",
       "fightbuttons: the pull touches a button that was never made",
       expect=FB + "a pull with no button made is quiet", script=S)

# --- no click out of sight

mutate(BF,
       "\tbutton:EnableMouse(Always() or keyLabel == nil)\n",
       "\tbutton:EnableMouse(true)\n",
       "fightbuttons: will of the forsaken takes a click out of sight",
       expect=FB + "out of sight it takes no click (will of the forsaken)", script=S)

mutate(BF,
       "\tbutton:EnableMouse(Always() or keyLabel == nil)\n",
       "\tbutton:EnableMouse(Always())\n",
       "fightbuttons: will of the forsaken with no key takes no click at all",
       expect=FB + "out of sight it takes no click (will of the forsaken)", script=S)

mutate(BF,
       "\tReadKey()\n\tSetMouse()\n\tPaint()\n",
       "\tReadKey()\n\tPaint()\n",
       "fightbuttons: the refresh leaves will of the forsaken's click as it was",
       expect=FB + "out of sight it takes no click (will of the forsaken)", script=S)

mutate(MP,
       "\tbutton:EnableMouse(Always() or keyLabel == nil)\n",
       "\tbutton:EnableMouse(true)\n",
       "fightbuttons: mend pet takes a click out of sight",
       expect=FB + "out of sight it takes no click (mend pet)", script=S)

mutate(MP,
       "\tbutton:EnableMouse(Always() or keyLabel == nil)\n",
       "\tbutton:EnableMouse(Always())\n",
       "fightbuttons: mend pet with no key takes no click at all",
       expect=FB + "out of sight it takes no click (mend pet)", script=S)

# --- Mend Pet out of sight until the pet is badly hurt

mutate(MP,
       "(always and (known and 0.35 or 0.6) or 0)",
       "(known and 0.35 or 0.6)",
       "fightbuttons: mend pet dim for every fight again",
       expect=FB + "mend pet is out of sight", script=S)

mutate(MP,
       "\tif lit or (always and not known) then\n",
       "\tif lit or not known then\n",
       "fightbuttons: mend pet's lines show with the health secret",
       expect="secret", script=S)

# --- the setting

mutate("Core.lua",
       "\t\t\tfightButtons = \"needed\",\n",
       "\t\t\tfightButtons = \"always\",\n",
       "fightbuttons: a new profile keeps the buttons dim for every fight",
       expect=FB + "a damaged setting", script=S)

mutate("Core.lua",
       "\toneOf(p, \"fightButtons\", { needed = true, always = true }, \"needed\")\n",
       "",
       "fightbuttons: a damaged setting is left as it is",
       expect=FB + "a damaged setting", script=S)

mutate(BF,
       "db.prompt.fightButtons == \"always\"",
       "db.prompt.fightButtons == \"never\"",
       "fightbuttons: All fight is never read",
       expect=FB + "all fight keeps", script=S)

# --- its place in the options window

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"appearance.fightButtons\",\n",
       "",
       "fightbuttons: the setting has no place in the window",
       expect="every control has one place in the options window", script=S)

# --- the In a fight page's reset

mutate("Options/Advanced.lua",
       "\"prompt.cureFightMods\", \"prompt.fightButtons\",\n",
       "\"prompt.cureFightMods\",\n",
       "fightbuttons: the In a fight page's reset leaves the setting",
       expect=FB + "the In a fight page's reset puts the setting back", script=S)
