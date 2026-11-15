# Mutations for hunt 3's finds in the looks and the outcome's words:
# tests/scenarios/hunt3-looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back the mistake
# the hunt fixed and names the scenario that has to object.


def _m(file, old, new, label, **kw):
    kw.setdefault("script", "runscenarios.py")
    mutate(file, old, new, "hunt3-looks: " + label, **kw)


# --- a scroll at rest stands ---------------------------------------------------

_m("Looks/Flow.lua",
   "\tlocal t = self.playing and now - (self.t0 or now) or 0\n",
   "\tlocal t = now - (self.t0 or now)\n",
   "a speed set on a scroll at rest counts the rest as travel",
   expect="hunt3-looks: a scroll at rest does not travel")

_m("Looks/Flow.lua",
   "\t\tif not self.playing then t = 0 end\n",
   "",
   "a scroll at rest is written where the clock would have taken it",
   expect="hunt3-looks: a scroll at rest does not travel")

# --- no arrival over a verdict --------------------------------------------------

_GUARD = " and not (self.outcomeOn or self.kit.OutcomeLive()) then\n\t\t\tself:StopLights()\n"
for _file, _cond, _style in (
        ("Looks/Warchief.lua", "\t\tif full and self.crestOK", "warchief"),
        ("Looks/Ebon.lua", "\t\tif full and self.runesOK", "ebon"),
        ("Looks/Gearworks.lua", "\t\tif full and self.kit.icon:IsShown()", "gearworks"),
        ("Looks/Stormcaller.lua", "\t\tif full", "stormcaller"),
        ("Looks/Lightbringer.lua", "\t\tif full and self.kit.icon:IsShown()", "lightbringer"),
        ("Looks/Archmage.lua", "\t\tif full and self.kit.icon:IsShown()", "archmage"),
        ("Looks/Fel.lua", "\t\tif full and not self.refused", "fel")):
    _m(_file, _cond + _GUARD, _cond + " then\n\t\t\tself:StopLights()\n",
       _style + " plays the arrival over a verdict",
       expect="hunt3-looks: " + _style + " plays no arrival over a verdict")

# Only what the look itself painted is asked: the outcome's own repaint, which
# comes before its words are written, plays the arrival.
_m("Looks/Warchief.lua",
   "\t\tif full and self.crestOK" + _GUARD,
   "\t\tif full and self.crestOK and not self.outcomeOn then\n\t\t\tself:StopLights()\n",
   "warchief plays the arrival in the outcome's own repaint",
   expect="hunt3-looks: warchief plays no arrival over a verdict")

# --- Warchief's soot -----------------------------------------------------------

_m("Looks/Warchief.lua",
   "\tif not self.kit.OutcomeLive() then self:SootUp(true) end\n",
   "\tself:SootUp(true)\n",
   "Warchief's soot is raised under a verdict at every scan",
   expect="hunt3-looks: Warchief's soot fades once under a verdict")

# --- a cure's outcome -----------------------------------------------------------

_m("Prompt/Paint.lua",
   "\tlocal cure = type(S.outcomeBuff) == \"string\" and S.outcomeBuff:sub(1, 5) == \"cure:\"\n",
   "\tlocal cure = false\n",
   "a cure's outcome is told as a buff's",
   expect="hunt3-looks: a cure's outcome says cured, not buffed, on glass")

_m("Prompt/Paint.lua",
   "\t\tif cure and S.outcomeKind ~= \"sent\" then named = nil end\n",
   "",
   "a look writes its own buff's verdict under a cure",
   expect="hunt3-looks: a cure's outcome says cured, not buffed, on warchief")
