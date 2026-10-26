# Mutations for hunt 38's fixes to the Ribbon look: tests/scenarios/hunt38-ribbon.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each undoes one fix.

RIBBON = "Looks/Ribbon.lua"


def _m(old, new, label, expect):
    mutate(RIBBON, old, new, "hunt38-ribbon: " + label, expect="hunt38-ribbon: " + expect,
           script="runscenarios.py")


_m("\tif text == self.mixedText then return end\n",
   "",
   "a refitted name is taken to the gold again",
   "a class colour is taken to the gold once")

_m("\tinkOnDark = true,\n",
   "",
   "a light panel colour darkens the codes on the cloth",
   "a light panel colour does not darken")

_m("\tfor i = 1, 3 do\n\t\tif math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return false end",
   "\tfor i = 1, 4 do\n\t\tif math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return false end",
   "the colour's opacity is a choice of colour",
   "a panel or text colour given another opacity")

_m("GOLD_INK[3], Clamp(alpha, 0, 1))\n\t\tself.nameInk = GOLD_INK",
   "GOLD_INK[3], 1)\n\t\tself.nameInk = GOLD_INK",
   "the lettering ignores the text colour's opacity",
   "a panel or text colour given another opacity")

_m("\tself.enamelLit:SetAlpha(0)\nend\n\nfunction Ribbon:Flourish(kind)",
   "\tself.enamelLit:SetAlpha(0)\n\tfor _, g in ipairs(self.fade) do g:Stop() end\n\tfor _, g in ipairs(self.slide) do g:Stop() end\nend\n\nfunction Ribbon:Flourish(kind)",
   "stopping the breath stops the arrival the same call started",
   "a new favour's arrival plays")

_m("\tif not icon then ov = math.max(ov, math.ceil((H - W * 0.85) / 2)) end\n",
   "",
   "the forked ends cross with no icon on a narrow tall prompt",
   "with no icon the forked ends never cross")
