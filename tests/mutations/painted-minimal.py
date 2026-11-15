# Mutations for Minimal's painting (Prompt/Panel.lua, the dressing after the
# framed look's, and ApplyStyle's choice of a dressing's `earlier`): the
# painting worn and the bezel's square gone; Earlier art giving back the
# hairline dressing; a prompt too narrow keeping the hairline; the words
# starting on the pane; a fight greying the painting.
# Each is caught by the scenario that names it (tests/scenarios/painted-minimal.lua).

S = "runscenarios.py"
P = "Prompt/Panel.lua"

mutate(P,
       "\t\t\tR.bezel:Hide()\n\t\t\tR.bezelHover:Hide()\n\t\t\tR.iconShade:Hide()\n\t\t\tPlace(art, g)\n",
       "\t\t\tR.bezelHover:Hide()\n\t\t\tR.iconShade:Hide()\n\t\t\tPlace(art, g)\n",
       "painted-minimal: the bezel's square drawn over the painted socket",
       expect="painted-minimal: Minimal wears its painting and none of its own frame", script=S)

mutate(P,
       "\tif dress and dress.Wanted and not dress:Wanted(p) then dress = dress.earlier end\n",
       "\tif dress and dress.Wanted and not dress:Wanted(p) then dress = nil end\n",
       "painted-minimal: Earlier art leaves Minimal without its hairline",
       expect="painted-minimal: Earlier art brings Minimal's hairline and bezel back", script=S)

mutate(P,
       "\t\t\treturn Painted.Layout(d, p.width, p.height, p.fontSize).unit >= p.height * SMALLEST\n",
       "\t\t\treturn true\n",
       "painted-minimal: the painting drawn smaller than a narrow prompt",
       expect="painted-minimal: the pieces follow the prompt's size", script=S)

mutate(P,
       "\t\t\treturn setmetatable({ width = wide }, { __index = p }), g.textX, room\n",
       "\t\t\treturn setmetatable({ width = wide }, { __index = p }), textX, room\n",
       "painted-minimal: the words laid where Minimal always started them, off the pane",
       expect="painted-minimal: the icon sits in the socket, the words start on the pane", script=S)

mutate(P,
       "\t\t\tPainted.Tone(self, k, k, k, self.fight == true)\n",
       "\t\t\tPainted.Tone(self, 1, 1, 1, false)\n",
       "painted-minimal: a fight leaves the painting in colour",
       expect="painted-minimal: a fight greys the painting", script=S)
