# Toast's painted frame (Looks/Toast.lua's paintedHides, PaintedPlace and its
# Iron's Tone line): judged by tests/scenarios/painted-toast.lua.

TOAST = "Looks/Toast.lua"
S = "runscenarios.py"

mutate(TOAST,
       "\tpaintedHides = { \"shadow\", \"body\", \"border\", \"medallion\", \"rim\", \"seam\", \"ring\", \"shade\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"medallion\", \"rim\", \"seam\", \"ring\", \"shade\", \"keyChip\" },\n",
       "painted-toast: the banner's own body and rails drawn under the painting",
       expect="painted-toast: Toast wears its painting and none of its own frame",
       script=S)

mutate(TOAST,
       "\tpaintedHides = { \"shadow\", \"body\", \"border\", \"medallion\", \"rim\", \"seam\", \"ring\", \"shade\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"body\", \"border\", \"shade\", \"keyChip\" },\n",
       "painted-toast: the old medallion's gold drawn over the painted one",
       expect="painted-toast: Toast wears its painting and none of its own frame",
       script=S)

mutate(TOAST,
       "\tself.textX = g.textX\n\n\t-- The medallion: the enamel",
       "\n\t-- The medallion: the enamel",
       "painted-toast: the lines kept beside the earlier medallion, not in the well",
       expect="painted-toast: the icon sits in the socket, the words start in the well",
       script=S)

mutate(TOAST,
       "\tlocal dy = self.H / 2 - g.textY\n",
       "\tlocal dy = self.H / 2 - g.textY + g.unit * 0.3\n",
       "painted-toast: the lines lifted off the well",
       expect="painted-toast: the icon sits in the socket, the words start in the well",
       script=S)

mutate(TOAST,
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -9, 0)\n",
       "painted-toast: the key's letter off the keycap's middle",
       expect="painted-toast: the icon sits in the socket, the words start in the well and the key is on the keycap",
       script=S)

mutate(TOAST,
       "\tns.Looks.Painted.Tone(self, v, v, v, on)\n",
       "",
       "painted-toast: a fight leaves the painting gold",
       expect="painted-toast: a fight greys the painting",
       script=S)

mutate(TOAST,
       "\tfor _, t in ipairs({ self.band, self.glow, self.ringHover, self.ringWarm }) do Disc(t, art, cx, cy, band) end\n",
       "",
       "painted-toast: the enamel left where the earlier medallion had it",
       expect="painted-toast: the enamel, the clock, the count and the list",
       script=S)

mutate(TOAST,
       "\tself.listX0 = cx + reach + 1\n",
       "\tself.listX0 = cx + 4\n",
       "painted-toast: the list's drawer over the painted medallion",
       expect="painted-toast: the enamel, the clock, the count and the list",
       script=S)

mutate(TOAST,
       "\tself.clockY = -(g.wellBottom - 0.07 * unit)\n",
       "\tself.clockY = -(g.wellBottom + 0.12 * unit)\n",
       "painted-toast: the favour clock off the well",
       expect="painted-toast: the enamel, the clock, the count and the list",
       script=S)

mutate(TOAST,
       "\t\t\t\tself.chipBox:SetPoint(\"RIGHT\", kit.art, \"RIGHT\", -(self.chipInset or 9), 0)\n",
       "\t\t\t\tself.chipBox:SetPoint(\"RIGHT\", kit.art, \"RIGHT\", -9, 0)\n",
       "painted-toast: the count's chip on the keycap",
       expect="painted-toast: the enamel, the clock, the count and the list",
       script=S)
