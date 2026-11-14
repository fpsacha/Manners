# Mutations for the second review of the redrawn looks (Looks/Letter.lua,
# Looks/Ribbon.lua) and of the Look page's cards (Options/Window/
# WidgetsTheme.lua). Each undoes one fix and is caught by the scenario in
# tests/scenarios/looks-redrawn-review2.lua that names it.

S = "runscenarios.py"

LETTER = "Looks/Letter.lua"
RIBBON = "Looks/Ribbon.lua"

# The arrival played for a new favour whatever is on the panel.
mutate(LETTER,
       "\t\tif full and not (self.outcomeOn or self.kit.OutcomeLive()) then\n",
       "\t\tif full then\n",
       "looks-redrawn-review2: Letter plays the arrival over a verdict",
       expect="looks-redrawn-review2: Letter does not play the arrival at a scan under a verdict", script=S)

# Only what the look itself painted is asked: the outcome's own repaint, which
# comes before its words are written, plays the arrival.
mutate(LETTER,
       "\t\tif full and not (self.outcomeOn or self.kit.OutcomeLive()) then\n",
       "\t\tif full and not self.outcomeOn then\n",
       "looks-redrawn-review2: Letter plays the arrival in the outcome's own repaint",
       expect="looks-redrawn-review2: Letter does not play the arrival in an outcome's own repaint", script=S)

# A reason painted under a verdict takes the signed flourish away.
mutate(LETTER,
       "\t-- (ClearOutcome) or with a refusal (Flourish).\n"
       "\tlocal k = self.combat and DIM_SEAL or 1\n",
       "\t-- (ClearOutcome) or with a refusal (Flourish).\n"
       "\tself.signed = nil\n"
       "\tself.swash:Hide()\n"
       "\tlocal k = self.combat and DIM_SEAL or 1\n",
       "looks-redrawn-review2: Letter's reason takes the signed flourish away",
       expect="looks-redrawn-review2: Letter's signed flourish stands", script=S)

# The pen's reach left as the last paint's list had it.
mutate(LETTER,
       "\tif not hung and self.wroteAt == GetTime() then self:Reach() end\n",
       "",
       "looks-redrawn-review2: Letter's pen stops at the name under a list hung with the arrival",
       expect="looks-redrawn-review2: Letter's pen crosses the sheet when a list hangs with the arrival", script=S)

mutate(LETTER,
       "\t\t\tif self.wroteAt == GetTime() then self:Reach() end\n",
       "",
       "looks-redrawn-review2: Letter's pen crosses the sheet for a list that has gone",
       expect="looks-redrawn-review2: Letter's pen stops at the lines when the list has gone", script=S)

# The outcome's headline taken to the lettering's gold like a class colour.
mutate(RIBBON,
       "\tif self.headline then\n"
       "\t\tself.mixedText = text\n"
       "\t\treturn\n"
       "\tend\n",
       "",
       "looks-redrawn-review2: Ribbon takes the headline's red and green to the gold",
       expect="looks-redrawn-review2: Ribbon's one-line headline keeps", script=S)

# The whole entrance, its settle included, read as the panel coming up.
mutate(RIBBON,
       "\t\tand GetTime() - (art.introAt or GetTime()) < (intro.rise or math.huge))\n",
       "\t\t)\n",
       "looks-redrawn-review2: Ribbon fades the cloth in through the entrance's settle",
       expect="looks-redrawn-review2: Ribbon's cloth is not faded in from nothing in the entrance's settle", script=S)

# The entrance's start never noted: the look has no time to go by.
mutate("Prompt/Effects.lua",
       "\t\tR.art.introCalm:Stop()\n"
       "\t\tR.art.introAt = GetTime()\n",
       "\t\tR.art.introCalm:Stop()\n",
       "looks-redrawn-review2: the entrance's start is not noted",
       expect="looks-redrawn-review2: Ribbon's cloth is not faded in from nothing in the entrance's settle", script=S)

# A card's description capped at two lines again.
mutate("Options/Window/WidgetsTheme.lua",
       "\tcard.desc = W.Wrapping(W.Text(card, T.fonts.small, T.hint))\n",
       "\tcard.desc = W.Wrapping(W.Text(card, T.fonts.small, T.hint))\n"
       "\tif card.desc.SetMaxLines then card.desc:SetMaxLines(2) end\n",
       "looks-redrawn-review2: a card's description capped at two lines",
       expect="looks-redrawn-review2: every card's description is whole at the window's smallest", script=S)
