# Mutations for the Luxe look read as the game draws it:
# tests/scenarios/readable-luxe.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back what 1.5.0
# shipped, or a near miss of the 1.5.1 fix, and names the rule that has to
# object: the icon drawn clean, the text on a dark ground, the chip off the
# icon.

LUXE = "Looks/Luxe.lua"

# --- the tag and the chip ---------------------------------------------------

# 1.5.0's tag: the reason's own colour, faint -- light in the game.
mutate(LUXE,
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.08, 0.9\n",
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 1, 1, 0.9\n",
       "readable-luxe: the tag filled in the reason's full colour",
       expect="the reason line reads",
       script="runscenarios.py")

# Dark, but faint enough that how the game weighs alpha decides it.
mutate(LUXE,
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.08, 0.9\n",
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.08, 0.5\n",
       "readable-luxe: the tag's fill left see-through",
       expect="the tag's fill is not solid enough",
       script="runscenarios.py")

# The fight dims the words and the tag stays as light as at rest.
mutate(LUXE,
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.08, 0.9\n",
       "local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.2, 0.9\n",
       "readable-luxe: the tag no darker in a fight",
       expect="the reason line reads",
       script="runscenarios.py")

# The fight never repaints the tag, so its darker ground never comes.
mutate(LUXE,
       "\t-- Its ground darker in a fight, and back after.\n\tself:PaintPill()\n",
       "",
       "readable-luxe: the tag not repainted for a fight",
       expect="the reason line reads",
       script="runscenarios.py")

# 1.5.0's chip: white at a whisper, which the game drew light.
mutate(LUXE,
       "\t\tt:SetVertexColor(NEUTRAL[1] * PILL_DARK, NEUTRAL[2] * PILL_DARK, NEUTRAL[3] * PILL_DARK, PILL_ALPHA)\n",
       "\t\tt:SetVertexColor(1, 1, 1, 0.075)\n",
       "readable-luxe: the count chip left pale",
       expect="the count chip's fill is not solid enough",
       script="runscenarios.py")

# --- light under the name ---------------------------------------------------

# 1.5.0's outcome light, which the game draws twice as bright.
mutate(LUXE,
       "local HOVER_LIGHT, RESULT_LIGHT = 0.035, 0.07\n",
       "local HOVER_LIGHT, RESULT_LIGHT = 0.035, 0.16\n",
       "readable-luxe: the outcome's light too bright under the name",
       expect="the name line reads",
       script="runscenarios.py")

# The cursor's light turned up.
mutate(LUXE,
       "local HOVER_LIGHT, RESULT_LIGHT = 0.035, 0.07\n",
       "local HOVER_LIGHT, RESULT_LIGHT = 0.12, 0.07\n",
       "readable-luxe: the cursor's light too bright under the name",
       expect="the name line reads",
       script="runscenarios.py")

# The reason's wash reaching under the name again, as it did at half the card.
mutate(LUXE,
       "\t\tt:SetWidth(math.min(math.floor(W * 0.52), textX + 1))\n",
       "\t\tt:SetWidth(math.floor(W * 0.52))\n",
       "readable-luxe: the wash runs under the name",
       expect="the name line reads",
       script="runscenarios.py")

# --- over the icon ----------------------------------------------------------

# A layer the full size of the icon, drawn over it: 1.5.0's shade.
mutate(LUXE,
       "\tself.rim:SetTexture(ART .. (round and \"IconRimRound\" or \"IconRim\"))\n",
       "\tself.rim:SetTexture(ART .. (round and \"IconMaskRound\" or \"IconMask\"))\n",
       "readable-luxe: a shade over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# The spine's bloom reaching onto the icon, as it did by five units.
mutate(LUXE,
       "\tlocal glowW = half + math.max(spineW / 2, math.min(half, reach))\n",
       "\tlocal glowW = 2 * half\n",
       "readable-luxe: the spine's bloom on the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# The outcome's light over the whole card, icon and all.
mutate(LUXE,
       "\tPlaceSlice(self.result, self.resultFrame, self.resultFrame, -clearX, 0, 0, 0)\n",
       "\tPlaceSlice(self.result, self.resultFrame, self.resultFrame, 0, 0, 0, 0)\n",
       "readable-luxe: the outcome's light over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# The cursor's light over the whole card.
mutate(LUXE,
       "\tPlaceSlice(self.hoverLight, self.hoverFrame, self.hoverFrame, -clearX, 0, 0, 0)\n",
       "\tPlaceSlice(self.hoverLight, self.hoverFrame, self.hoverFrame, 0, 0, 0, 0)\n",
       "readable-luxe: the cursor's light over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# The cursor's wash drawn above the icon rather than under it.
mutate(LUXE,
       "\tself.hoverWash = tex(art, \"BORDER\", 2, \"Wash\", \"ADD\")\n",
       "\tself.hoverWash = tex(art, \"OVERLAY\", 2, \"Wash\", \"ADD\")\n",
       "readable-luxe: the cursor's wash over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# The crossing light starting at the card's edge, over the icon, for longer
# than a flourish may.
mutate(LUXE,
       "\tself.sheenFrame:SetPoint(\"LEFT\", art, \"LEFT\", clearX, 0)\n",
       "\tself.sheenFrame:SetPoint(\"LEFT\", art, \"LEFT\", 0, 0)\n",
       "readable-luxe: the crossing light over the icon",
       expect="is drawn over the spell icon",
       script="runscenarios.py")

# --- the chip -----------------------------------------------------------------

mutate(LUXE,
       "\tself.chipBox:SetPoint(\"RIGHT\", kit.textLayer, \"RIGHT\", -8, twoLine and self.nameY or 0)\n",
       "\tself.chipBox:SetPoint(\"LEFT\", kit.textLayer, \"LEFT\", 20, twoLine and self.nameY or 0)\n",
       "readable-luxe: the count chip on the icon",
       expect="the count chip covers the icon",
       script="runscenarios.py")
