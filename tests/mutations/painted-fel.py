# Mutations for Fel (titled Warlock) in its painted frame (Looks/Fel.lua's
# paintedHides, PaintedPlace, Dull and Tint, its Apply's resets): its own frame
# hidden under the painting, the words in the well, the key on the keycap, the
# fire on the painting's rail, the list clear of what hangs under the bar, the
# eye's light, a fight greying the painting, and Earlier art giving every part
# of its own art back. Each is caught by tests/scenarios/painted-fel.lua.

S = "runscenarios.py"

mutate("Looks/Fel.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"flowTex\", \"disc\", \"horns\", \"sigil\", \"runes\", \"shard\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"flowTex\", \"disc\", \"horns\", \"sigil\", \"runes\", \"shard\", \"keyChip\" },\n",
       "painted-fel: the felsteel slab drawn under the painting",
       expect="Fel's own frame is drawn under the painting", script=S)

mutate("Looks/Fel.lua",
       "\tself.textX = g.textX\n\tself.plateIn, self.plateX",
       "\tself.plateIn, self.plateX",
       "painted-fel: the words where the slab had them",
       expect="the well's text at", script=S)

mutate("Looks/Fel.lua",
       "\tself.chipInset = math.ceil(self.W - keyL) + 3\n",
       "",
       "painted-fel: the words run over the keycap",
       expect="past the keycap", script=S)

mutate("Looks/Fel.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -self.chipInset, 0)\n",
       "painted-fel: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Fel.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * f, pc[2] * f, pc[3] * f, on)\n",
       "",
       "painted-fel: a fight leaves the painting alone",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Fel.lua",
       "local PAINT_FIRE_FOOT, PAINT_FIRE_GAP, PAINT_FIRE_DIM = 0.99, 0.02, 0.55\n",
       "local PAINT_FIRE_FOOT, PAINT_FIRE_GAP, PAINT_FIRE_DIM = 1.25, 0.02, 0.55\n",
       "painted-fel: the fire hung under the painting's rail",
       expect="not on the rail under the well", script=S)

mutate("Looks/Fel.lua",
       "\tlocal gap = self.listGap or 0\n",
       "\tlocal gap = 0\n",
       "painted-fel: the list under what the painting hangs",
       expect="under the painting that hangs", script=S)

mutate("Looks/Fel.lua",
       "\tif not stripe and ns.Looks.Painted.On(self) then gr, gg, gb = EYELIGHT[1], EYELIGHT[2], EYELIGHT[3] end\n",
       "",
       "painted-fel: the shard's violet over the green eye",
       expect="not the eye's green", script=S)

mutate("Looks/Fel.lua",
       "\tself.listX0, self.listX1, self.listGap = nil, nil, nil\n",
       "",
       "painted-fel: Earlier art's list on the painting's ends",
       expect="the list keeps the painting's ends", script=S)

mutate("Looks/Fel.lua",
       "\t\tns.Looks.Dim(t, 1)\n",
       "",
       "painted-fel: Earlier art's fire left faint",
       expect="the fire is still drawn faint", script=S)
