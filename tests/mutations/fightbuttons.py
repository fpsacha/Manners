# Mutations for when the fight buttons show (Prompt/BreakFree.lua,
# Prompt/MendPet.lua, `prompt.fightButtons` in Core.lua, its place in the
# options window). Caught by tests/scenarios/fightbuttons.lua; each undoes one
# rule: out of sight until the need, no tooltip out of sight, a new fight at
# alpha 0, All fight keeping the dim buttons, the setting's default and repair.

S = "runscenarios.py"
BF = "Prompt/BreakFree.lua"
MP = "Prompt/MendPet.lua"
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
       "\t\tbutton:SetAlpha(fadeTo)\n\t\tfader:Hide()\n\t\treturn\n",
       "\t\treturn\n",
       "fightbuttons: the pull leaves the last alpha on the button",
       expect=FB + "a new fight starts out of sight", script=S)

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
