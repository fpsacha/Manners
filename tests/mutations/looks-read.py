# Mutations for the words' contrast on every look (tests/scenarios/
# looks-read.lua; tools/audit_look_contrast.py measures the same on the
# pictures): the ground a look states for its words, the floor the reason line
# and the verdict are held to, the list's grey, both lines' shadows, and the
# name kept at the size the player set while the tags give way.

S = "runscenarios.py"
NAME = "looks-read: %s: the words read on the look's own ground"

# --- the ground a look states ---------------------------------------------------

# The hide, the cloth and the iron are lighter than the panel colour behind
# them: judged against that, a class colour read on paper and not on the prompt.
mutate("Looks/Leather.lua",
       "\tink.lo, ink.hi = HIDE_LUM, HIDE_LUM\n",
       "",
       "looks-read: leather: its words judged against the panel colour, not the hide",
       expect="looks-read: leather:", script=S)

mutate("Looks/Ribbon.lua",
       "local CLOTH_LUM = 0.115\n",
       "local CLOTH_LUM = 0.01\n",
       "looks-read: ribbon: its words judged against a cloth darker than it is",
       expect="looks-read: ribbon:", script=S)

mutate("Looks/Forge.lua",
       "local PLATE_LO, PLATE_HI = 0.14, 0.33\n",
       "local PLATE_LO, PLATE_HI = 0.14, 0.30\n",
       "looks-read: forge: its words judged against iron darker than it is",
       expect="looks-read: forge:", script=S)

# --- the floors -------------------------------------------------------------------

mutate("Looks/Fel.lua",
       "local SUB_CONTRAST = 7\n",
       "local SUB_CONTRAST = 3\n",
       "looks-read: fel: the reason line held to a contrast nobody reads at",
       expect="looks-read: fel:", script=S)

# Coloured words held to large text's 3:1 again: the death knight's red and
# the shaman's blue on the name, on the default panel.
mutate("Prompt/Text.lua",
       "local CODE_CONTRAST, TEXT_CONTRAST = 5, 4.5\n",
       "local CODE_CONTRAST, TEXT_CONTRAST = 3.0, 4.5\n",
       "looks-read: a class's colour on the name held to large text's line",
       expect="looks-read: framed:", script=S)

# A colour that has to move stops at the line it was held to, not under it.
mutate("Prompt/Text.lua",
       "\t\tnr, ng, nb = Legible(fr, fg, fb, math.max(least, TEXT_CONTRAST))\n",
       "\t\tnr, ng, nb = Legible(fr, fg, fb, 3)\n",
       "looks-read: a colour code moved to under the line it failed",
       expect="looks-read: glass:", script=S)

# On parchment a byte's rounding takes an ink held to exactly 4.5:1 under it:
# the list's own ink, which no colour code's rule catches afterwards.
mutate("Looks/Letter.lua",
       "\tlocal lr, lg, lb = kit.Legible(ROW_INK[1], ROW_INK[2], ROW_INK[3], 4.5)\n",
       "\tlocal lr, lg, lb = kit.Legible(0.62, 0.50, 0.36, 1)\n",
       "looks-read: letter: the list's names in an ink too pale for the parchment",
       expect="looks-read: letter:", script=S)

# --- the shadows --------------------------------------------------------------------

mutate("Looks/Fel.lua",
       "\tkit.name:SetShadowColor(0, 0.03, 0, 0.95)\n",
       "\tkit.name:SetShadowColor(0, 0.03, 0, 0)\n",
       "looks-read: fel: the name with no shadow on the felsteel",
       expect="has neither a dark shadow nor an outline", script=S)

# --- the name at the size the player set ----------------------------------------------

for look in ("Wild", "Frost", "Fel", "Lightbringer"):
    mutate("Looks/%s.lua" % look,
           "\treturn width * base / size <= self.W - self.textX - math.max(room, self.chipInset or 18) + 0.5\n",
           "\treturn width * math.max(7, math.floor(base * 0.8 + 0.5)) / size <= self.W - self.textX"
           " - math.max(room, self.chipInset or 18) + 0.5\n",
           "looks-read: %s: the name drawn smaller so both tags can stay" % look.lower(),
           expect="looks-read: %s:" % look.lower(), script=S)
