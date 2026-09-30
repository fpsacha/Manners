# Mutations for the Toast look's legibility and restraint:
# tests/scenarios/readable-toast.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back one of the
# things that made the toast hard to read or loud in the game -- light under
# the text, art over the spell icon, the count on the icon, bright gold, a
# square frame, a glowing enamel, a cold body -- and names the check that has
# to object. The art itself is binary and cannot be mutated here; the same
# checks read it texel by texel, and these swap the files or colours the Lua
# draws with.

TOAST = "Looks/Toast.lua"

# --- the text on a dark ground ---------------------------------------------

# A banner lit to gold behind the text, a little see-through.
mutate(TOAST,
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.118, 0.072, 0.046 }, { 0.090, 0.055, 0.036 }, 1\n",
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.420, 0.310, 0.190 }, { 0.300, 0.220, 0.140 }, 0.95\n",
       "the toast's banner lit brown behind the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# The cursor's light laid across the whole banner, under the lines.
mutate(TOAST,
       "\tDisc(self.ringHover, art, cx, cy, rRing)\n",
       "\tBox(self.ringHover, art, left, top, W, bottom)\n",
       "the cursor's light under the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# The owed glow spread far past the medallion, under the name.
mutate(TOAST,
       "\tDisc(self.glow, art, cx, cy, rEnamel)\n",
       "\tDisc(self.glow, art, cx, cy, 3 * R)\n",
       "the owed glow under the text",
       expect="on its ground over a world",
       script="runscenarios.py")

# --- the icon drawn clean ---------------------------------------------------

# The gold ring drawn over the icon, as 1.5.0's medallion was.
mutate(TOAST,
       "\tself.ring = tex(art, \"ARTWORK\", -3, \"Gold\")\n",
       "\tself.ring = tex(art, \"OVERLAY\", -3, \"Gold\")\n",
       "the toast's ring over the icon",
       expect="lies over the spell icon's box",
       script="runscenarios.py")

# The well drawn over the icon rather than under it.
mutate(TOAST,
       "\tself.well = tex(art, \"ARTWORK\", -1, \"Disc\")\n",
       "\tself.well = tex(art, \"ARTWORK\", 1, \"Disc\")\n",
       "the toast's well over the icon",
       expect="lies over the spell icon's box",
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

# --- round 18: old gold, a round medallion, a warm body ---------------------

# The frame drawn from its flare's file: the glaring line of 1.5.1.
mutate(TOAST,
       "\tEach(self.border, \"SetTexture\", frameFile)\n",
       "\tEach(self.border, \"SetTexture\", frameFile .. \"Glow\")\n",
       "the frame drawn as light",
       expect="is gold as bright as",
       script="runscenarios.py")

# The medallion's rim at the ring's full brightness and more: not old gold.
mutate(TOAST,
       "local RIM = { 0.92, 0.92, 0.92 }\n",
       "local RIM = { 1.6, 1.4, 1.2 }\n",
       "the medallion's rim brightened",
       expect="is gold as bright as",
       script="runscenarios.py")

# A square frame round the icon: the medallion's edge drawn from a square
# file.
mutate(TOAST,
       "\tself.medallion = tex(art, \"ARTWORK\", -8, \"Disc\")\n",
       "\tself.medallion = tex(art, \"ARTWORK\", -8, \"Body\")\n",
       "a square frame round the icon",
       expect="is not round",
       script="runscenarios.py")

# The gold ring as thick as 1.5.1's, growing with the panel.
mutate(TOAST,
       "\tlocal well = ring - Clamp(H * 0.045, 1.5, 2.5)\n",
       "\tlocal well = ring - H * 0.09\n",
       "the gold ring thick",
       expect="the gold ring is",
       script="runscenarios.py")

# The icon shrunk inside the ring, which no longer hugs it.
mutate(TOAST,
       "\tlocal icon = 2 * iconR / MASK_FILL\n",
       "\tlocal icon = 1.7 * iconR / MASK_FILL\n",
       "the ring standing off the icon",
       expect="it should hug it",
       script="runscenarios.py")

# The enamel at the reason's full colour: a glowing band, not a dark one.
mutate(TOAST,
       "local ENAMEL_DARK = 0.48\n",
       "local ENAMEL_DARK = 1.0\n",
       "the enamel undarkened",
       expect="is not the reason colour darkened",
       script="runscenarios.py")

# The icon left square with rounding off (the default): a square in a dark
# round hole, the ring round only its corners.
mutate(TOAST,
       "\tlocal maskFile = ART .. \"IconMask\"\n",
       "\tlocal maskFile = ART .. (p.roundIcon and \"IconMask\" or \"Body\")\n",
       "the icon square with rounding off",
       expect="rounding is off and the icon is not round",
       script="runscenarios.py")

# The medallion's rim dimmed to a brown line: the gilded bezel gone, the
# enamel on a dark edge.
mutate(TOAST,
       "local RIM = { 0.92, 0.92, 0.92 }\n",
       "local RIM = { 0.66, 0.62, 0.58 }\n",
       "the medallion's rim dimmed",
       expect="too dark to read as gold",
       script="runscenarios.py")

# The list's drawer drawn from a file of pure light: its rail a glowing line.
mutate(TOAST,
       "\tself.drawer = Pieces(art, \"BORDER\", -2, ART .. \"Drawer\", nil, false, keep)\n",
       "\tself.drawer = Pieces(art, \"BORDER\", -2, ART .. \"BorderGlow\", nil, false, keep)\n",
       "the drawer's rail drawn as light",
       expect="is gold as bright as",
       script="runscenarios.py")

# The olive-black body of 1.5.1's in the game: no warmth in it.
mutate(TOAST,
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.118, 0.072, 0.046 }, { 0.090, 0.055, 0.036 }, 1\n",
       "local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.060, 0.058, 0.044 }, { 0.040, 0.039, 0.030 }, 1\n",
       "the body cold and olive",
       expect="is not a warm brown",
       script="runscenarios.py")
