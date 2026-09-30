# Mutations for the Toast look's legibility: tests/scenarios/readable-toast.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back one of the
# things that made 1.5.0's toast hard to read in the game -- light added under
# the text, art over the spell icon, the count on the icon -- and names the
# check that has to object. The art itself (the gloss and the shade the
# medallion drew over the icon) is binary and cannot be mutated here; the same
# check reads it texel by texel.

TOAST = "Looks/Toast.lua"

# --- the text on a dark ground ---------------------------------------------

# 1.5.0's banner: a warm brown lit to gold in its middle, a little see-through.
mutate(TOAST,
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.080, 0.056, 0.042 }, { 0.040, 0.029, 0.024 }, 1\n",
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.205, 0.145, 0.100 }, { 0.070, 0.050, 0.042 }, 0.95\n",
       "the toast's banner lit brown behind the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# The reason's light spilling right under the name, as it did.
mutate(TOAST,
       "\t\tt:SetSize(lightEnd - left, BH - 3)\n",
       "\t\tt:SetSize(2.03 * BH, BH - 3)\n",
       "the toast's bloom under the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# The outcome's wash and the cursor's across the whole banner.
mutate(TOAST,
       "\t\tBox(t, art, left + 1, top + 1, lightEnd, bottom - 1)\n",
       "\t\tBox(t, art, left + 1, top + 1, W - 1, bottom - 1)\n",
       "the toast's washes under the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# --- the icon drawn clean ---------------------------------------------------

# Every light of the look's drawn over the icon rather than under it.
mutate(TOAST,
       "\t\tlocal t = tex(parent or art, \"BORDER\", sublevel, file, \"ADD\")\n",
       "\t\tlocal t = tex(parent or art, \"OVERLAY\", sublevel, file, \"ADD\")\n",
       "the toast's lights over the icon",
       expect="lies over the spell icon's box",
       script="runscenarios.py")

# The favour clock's spark left on the line's end as it runs out, over the
# icon's corner.
mutate(TOAST,
       "\t\t\tmath.max(self.clockX + width, self.beadMin), self.clockY)\n",
       "\t\t\tself.clockX + width, self.clockY)\n",
       "the toast's clock spark over the icon",
       expect="lies over the spell icon's box",
       script="runscenarios.py")

# The medallion drawn smaller than the panel, its gold and enamel over the
# icon it frames.
mutate(TOAST,
       "\tself.medallion:SetSize(math.max(1, M), math.max(1, M))\n",
       "\tself.medallion:SetSize(math.max(1, M * 0.8), math.max(1, M * 0.8))\n",
       "the toast's medallion over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# --- the count off the icon -------------------------------------------------

# 1.5.0's coin on the medallion's lower right, over the icon.
mutate(TOAST,
       "\t\t\t\tself.chipBox:SetPoint(\"RIGHT\", self.keyBox, \"LEFT\", -4, 0)\n",
       "\t\t\t\tself.chipBox:SetPoint(\"CENTER\", kit.art, \"TOPLEFT\", self.cx + 0.36 * self.M,"
       " -(self.cy + 0.32 * self.M))\n",
       "the toast's count on the icon",
       expect="the count's chip covers the spell icon",
       script="runscenarios.py")
