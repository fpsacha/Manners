# Mutations for round 37, the options window redesign:
# tests/scenarios/ux-redesign.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back what the
# round 36 audit found, and names the scenario that objects.

S = "runscenarios.py"
THEME = "Options/Window/WidgetsTheme.lua"

# --- 1: the Luxe card's tag ------------------------------------------------

mutate(THEME, "\tHidePill(card, #pill.layers + 1)\n\t-- Slices made here, at layout, after the card was last painted: tinted now,\n"
       "\t-- or they stay the file's own white until the pointer passes over the card.\n"
       "\tTintLines(card, card.row and card.row.off)\n",
       "\tHidePill(card, #pill.layers + 1)\n",
       "ux-redesign: the Luxe tag's slices are left untinted at layout",
       expect="ux-redesign: the Luxe card's tag is tinted the first time the page is drawn", script=S)
