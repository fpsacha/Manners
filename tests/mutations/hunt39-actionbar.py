# Mutations for hunt 39, the prompt on an action bar and a controller
# (tests/scenarios/hunt39-actionbar.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each undoes one fix and names
# the check that has to object.

S = "runscenarios.py"
CHIP = "hunt39-actionbar: the key chip follows the controller's glyphs and the pad's modifier settings"
CURSOR = "hunt39-actionbar: another macro on the cursor is not the one Start here says to drop"

# A pad button with a modifier worked out once for the key and kept, whatever
# the client's glyphs or the CVars become.
mutate("Looks/Looks.lua",
       "\t\t\tif key ~= comboKey or made ~= comboMade then comboKey, comboMade, comboText = key, made, PadCombo(key) or false end\n",
       "\t\t\tif key ~= comboKey then comboKey, comboMade, comboText = key, made, PadCombo(key) or false end\n",
       "hunt39-actionbar: a pad combination kept for the key whatever the client's words become",
       expect=CHIP, script=S)

# Arcane's chip read once per key: a controller told apart later never shows.
mutate("Looks/Arcane.lua",
       "\t\tif type(GetBindingText) ~= \"function\" or KeyLabel(key) == self.keyLabel then return end\n",
       "\t\treturn\n",
       "hunt39-actionbar: Arcane's chip read once for a key",
       expect=CHIP, script=S)

# Any macro on the cursor is the one Start here says to drop.
mutate("Options/Start.lua",
       "\t\tif kind == \"macro\" and (type(index) ~= \"number\" or index == MacroIndex()) then return true end\n",
       "\t\tif kind == \"macro\" then return true end\n",
       "hunt39-actionbar: any macro on the cursor is the Manners macro",
       expect=CURSOR, script=S)
