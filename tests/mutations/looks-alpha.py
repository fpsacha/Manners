# Mutations for the one alpha (Looks/Looks.lua's Colour, Dim and Hold, and every
# look's use of them; tests/scenarios/looks-alpha.lua). The game keeps one alpha
# for a texture, so a colour given with an alpha of its own writes over what
# SetAlpha set. Each look has the helper undone at a real call site, where a
# light parked at nothing or dimmed is coloured: the scenario that takes that
# look through its states on a mock keeping one alpha, as the game does, must
# see the light come up. Then the helper itself, the dims that lie over a
# light's own alpha, and the lights whose strength their colour used to carry.

S = "runscenarios.py"
NAME = "looks-alpha: %s: a colour leaves every texture as faint as it was"

# --- each look, the helper undone at one call site ---------------------------

mutate("Looks/Glass.lua",
       "\tfor i = 1, 2 do Colour(self.eye[i], er, eg, eb) end\n",
       "\tfor i = 1, 2 do self.eye[i]:SetVertexColor(er, eg, eb, 1) end\n",
       "looks-alpha: glass: the gryphons' eyes coloured at full strength",
       expect=NAME % "glass", script=S)

# The bezel's lifted twin is Panel.lua's, which glass, framed and minimal all
# wear: parked at nothing until the cursor comes.
mutate("Prompt/Panel.lua",
       "\tns.Looks.Colour(R.bezelHover, hr, hg, hb)\n",
       "\tR.bezelHover:SetVertexColor(hr, hg, hb, 1)\n",
       "looks-alpha: framed: the bezel's hover twin coloured at full strength",
       expect=NAME % "framed", script=S)

mutate("Prompt/Panel.lua",
       "\tns.Looks.Colour(R.bezelHover, hr, hg, hb)\n",
       "\tR.bezelHover:SetVertexColor(hr, hg, hb, 1) \n",
       "looks-alpha: minimal: the bezel's hover twin coloured at full strength",
       expect=NAME % "minimal", script=S)

mutate("Looks/Luxe.lua",
       "\tfor _, t in ipairs(self.ground) do Dim(t, ground) end\n",
       "\tfor _, t in ipairs(self.ground) do t:SetAlpha(ground) end\n",
       "looks-alpha: luxe: the fight's dim written over the shadow's own alpha",
       expect="looks-alpha: luxe: a fight's dim lies over the shadow's own alpha", script=S)

mutate("Looks/Toast.lua",
       "\tColour(self.ringArrive, r, g, b)\n",
       "\tself.ringArrive:SetVertexColor(r, g, b, 0.55)\n",
       "looks-alpha: toast: the arrival's ring left lit by its colour",
       expect=NAME % "toast", script=S)

mutate("Looks/Arcane.lua",
       "\tDim(self.well, ink)\n",
       "\tself.well:SetAlpha(ink)\n",
       "looks-alpha: arcane: the fight's dim written over the well's own alpha",
       expect="looks-alpha: arcane: a fight's dim lies over each light's own alpha", script=S)

mutate("Looks/Ribbon.lua",
       "\tColour(self.sweep, 1, 0.90, 0.62)\n",
       "\tself.sweep:SetVertexColor(1, 0.90, 0.62, 0.9)\n",
       "looks-alpha: ribbon: the shine left lit by its colour",
       expect=NAME % "ribbon", script=S)

mutate("Looks/Letter.lua",
       "\tColour(self.flash, GOLD[1], GOLD[2], GOLD[3])\n\tPlayAll(self.flashAnims)\n",
       "\tself.flash:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)\n\tPlayAll(self.flashAnims)\n",
       "looks-alpha: letter: the seal's flash coloured at full strength",
       expect=NAME % "letter", script=S)

mutate("Looks/Leather.lua",
       "\t\tColour(self.ringFlash, 1.00, 0.42, 0.20)\n",
       "\t\tself.ringFlash:SetVertexColor(1.00, 0.42, 0.20, 1)\n",
       "looks-alpha: leather: the refusal's flash coloured at full strength",
       expect=NAME % "leather", script=S)

mutate("Looks/Forge.lua",
       "\t\tColour(self.bezelWarm, hr, hg, hb)\n",
       "\t\tself.bezelWarm:SetVertexColor(hr, hg, hb, 1)\n",
       "looks-alpha: forge: the bezel's breath coloured at full strength",
       expect=NAME % "forge", script=S)

mutate("Looks/Archmage.lua",
       "\tColour(self.halo, cr, cg, cb)\n",
       "\tself.halo:SetVertexColor(cr, cg, cb, 1)\n",
       "looks-alpha: archmage: the halo coloured at full strength",
       expect=NAME % "archmage", script=S)

mutate("Looks/Lightbringer.lua",
       "\tColour(self.halo, cr, cg, cb)\n",
       "\tself.halo:SetVertexColor(cr, cg, cb, 1)\n",
       "looks-alpha: lightbringer: the halo coloured at full strength",
       expect=NAME % "lightbringer", script=S)

mutate("Looks/Fel.lua",
       "\tColour(self.hot, fr, fg, fb)\n",
       "\tself.hot:SetVertexColor(fr, fg, fb, 1)\n",
       "looks-alpha: fel: the flash coloured at full strength",
       expect=NAME % "fel", script=S)

mutate("Looks/Wild.lua",
       "\tColour(self.hot, fr, fg, fb)\n",
       "\tself.hot:SetVertexColor(fr, fg, fb, 1)\n",
       "looks-alpha: wild: the flash coloured at full strength",
       expect=NAME % "wild", script=S)

mutate("Looks/Frost.lua",
       "\tColour(self.hot, fr, fg, fb)\n",
       "\tself.hot:SetVertexColor(fr, fg, fb, 1)\n",
       "looks-alpha: frost: the flash coloured at full strength",
       expect=NAME % "frost", script=S)

# --- the helper itself --------------------------------------------------------

# The alpha put back after the colour: without it a client that reads an alpha
# left out as 1 lights everything coloured.
mutate("Looks/Looks.lua",
       "\tt:SetVertexColor(r, g, b)\n\tt:rawSetAlpha(t.restAlpha)\nend\n\nfunction Looks.Dim",
       "\tt:SetVertexColor(r, g, b)\nend\n\nfunction Looks.Dim",
       "looks-alpha: a colour that does not put the resting alpha back",
       expect="with an alpha left out read as 1", script=S)

# The colour given with the alpha in the one call: the mock multiplies the two,
# the game keeps the last.
mutate("Looks/Looks.lua",
       "\tt:SetVertexColor(r, g, b)\n\tt:rawSetAlpha(t.restAlpha)\nend\n\nfunction Looks.Dim",
       "\tt:SetVertexColor(r, g, b, t.restAlpha)\n\tt:rawSetAlpha(t.restAlpha)\nend\n\nfunction Looks.Dim",
       "looks-alpha: a colour that carries its alpha in the one call",
       expect="with the game's one alpha", script=S)

# A dim that forgets the light's own alpha.
mutate("Looks/Looks.lua",
       "\tt.restAlpha = t.ownAlpha * by\n",
       "\tt.restAlpha = by\n",
       "looks-alpha: a dim that writes over a light's own alpha",
       expect="looks-alpha: toast: a fight's dim lies over the clock's own alpha", script=S)

# An own alpha given in a fight forgets the dim over it.
mutate("Looks/Looks.lua",
       "\t\tt.restAlpha = alpha * (t.dimBy or 1)\n",
       "\t\tt.restAlpha = alpha\n",
       "looks-alpha: a colour's own alpha that forgets the dim over it",
       expect="in a fight, after a reason's colour,", script=S)

# --- the dims ------------------------------------------------------------------

mutate("Looks/Toast.lua",
       "\tDim(self.ember, on and CLOCK_FIGHT or 1)\n",
       "\tself.ember:SetAlpha(on and CLOCK_FIGHT or 1)\n",
       "looks-alpha: toast: the fight's dim written over the clock's own alpha",
       expect="looks-alpha: toast: a fight's dim lies over the clock's own alpha", script=S)

mutate("Looks/Arcane.lua",
       "\t\tself.wash:SetAlpha(o[4])\n",
       "\t\tself.wash:SetAlpha(1)\n",
       "looks-alpha: arcane: the outcome's wash at full strength",
       expect="the outcome's wash stands at", script=S)

mutate("Looks/Arcane.lua",
       "\t\tself.washAnim.fade:SetFromAlpha(o[4])\n",
       "",
       "looks-alpha: arcane: the outcome's wash fading from full strength",
       expect="the wash fades from", script=S)

# --- the lights' own strength ---------------------------------------------------

mutate("Looks/Toast.lua",
       "\tg.to = on and HOVER[4] or 0\n",
       "\tg.to = on and 1 or 0\n",
       "looks-alpha: toast: the cursor's light on the gold at full strength",
       expect="under the cursor the gold's light stands at", script=S)

mutate("Looks/Toast.lua",
       "\tAlpha(warm, 0, PULSE_WARM, BREATH, 1, nil, \"IN_OUT\")\n",
       "\tAlpha(warm, 0, 1, BREATH, 1, nil, \"IN_OUT\")\n",
       "looks-alpha: toast: the warmed ring pulsing to full strength",
       expect="the warm goes to", script=S)

mutate("Looks/Toast.lua",
       "\tColour(self.ringHover, HOVER[1], HOVER[2], HOVER[3])\n",
       "\tself.ringHover:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], HOVER[4])\n",
       "looks-alpha: toast: the cursor's light carrying its strength in its colour",
       expect="the cursor's colour carries an alpha", script=S)

mutate("Looks/Ribbon.lua",
       "local SWEEP_PEAK = 0.5\n",
       "local SWEEP_PEAK = 1\n",
       "looks-alpha: ribbon: the shine at full strength",
       expect="looks-alpha: ribbon: the shine along the cloth goes to its own strength", script=S)

mutate("Looks/Letter.lua",
       "local HILITE_PEAK = 0.20\n",
       "local HILITE_PEAK = 1\n",
       "looks-alpha: letter: the cursor's light on the seal at full strength",
       expect="the cursor on the panel does not light the seal", script=S)
