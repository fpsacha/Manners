# Mutations for hunt 40's two layout faults: tests/scenarios/hunt40-layout.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back the mistake
# the hunt fixed and names the scenario that has to object.


def _m(file, old, new, label, **kw):
    kw.setdefault("script", "runscenarios.py")
    mutate(file, old, new, "hunt40-layout: " + label, **kw)


SWEEP = "hunt40-layout: the name never overlaps the count or the key chip, "

# --- the count chip's room follows the count shown -----------------------------

_m("Looks/Luxe.lua",
   "\t\tkit.fit.chipRoom = math.max(self.roomBase or 0, chipW + 14)\n",
   "\t\tkit.fit.chipRoom = self.roomBase or 0\n",
   "Luxe keeps the room of two digits for a count of three",
   expect=SWEEP + "luxe")

_m("Looks/Toast.lua",
   "\t\tkit.fit.chipRoom = math.max(self.roomBase or 0, math.ceil(self.countW) + 15)\n",
   "\t\tkit.fit.chipRoom = self.roomBase or 0\n",
   "Toast keeps the room of two digits for a count of three",
   expect=SWEEP + "toast")

_m("Looks/Arcane.lua",
   "\t\tkit.fit.chipRoom = math.max(self.roomBase or 0, 10 + self.countW + 4)\n",
   "\t\tkit.fit.chipRoom = self.roomBase or 0\n",
   "Arcane keeps the room of two digits for a count of three",
   expect=SWEEP + "arcane")

_m("Looks/Arcane.lua",
   "\tif self.badgeUp then self:PlaceBadge() end\n",
   "",
   "Arcane's badge stays where the keycap was after the keycap steps aside",
   expect=SWEEP + "arcane")

_m("Looks/Ribbon.lua",
   "\t\tfit.chipRoom = math.max(self.roomBase or 0, math.floor(beside + 0.5) + 5 + self.rightBase)\n",
   "\t\tfit.chipRoom = self.roomBase or 0\n",
   "Ribbon keeps the room of two digits for a count of three",
   expect=SWEEP + "ribbon")

_m("Looks/Letter.lua",
   "\t\t\tself.wordsW = (kit.TextWidth(count) or self.sub) + 9\n",
   "\t\t\tself.wordsW = 0\n",
   "Letter's room for the count ignores its words",
   expect=SWEEP + "letter")

# --- a change of the display styles the prompt again ---------------------------

_m("Core.lua",
   "\t\t\"UI_SCALE_CHANGED\",\n",
   "",
   "a change of the UI scale is not listened for",
   expect="hunt40-layout: UI_SCALE_CHANGED styles the prompt again")

_m("Core.lua",
   "\t\t\"DISPLAY_SIZE_CHANGED\",\n",
   "",
   "a change of the screen's size is not listened for",
   expect="hunt40-layout: DISPLAY_SIZE_CHANGED styles the prompt again")

_m("Core.lua",
   "addon.DISPLAY_SIZE_CHANGED = addon.UI_SCALE_CHANGED\n",
   "",
   "a change of the screen's size has no handler",
   expect="hunt40-layout: DISPLAY_SIZE_CHANGED styles the prompt again")

_m("Core.lua",
   "\tif ns.Prompt then ns.Guard(\"restyle for the display\", ns.Prompt.ApplyStyle, ns.Prompt) end\n",
   "\tif ns.Prompt and not InCombatLockdown() then ns.Guard(\"restyle for the display\", ns.Prompt.ApplyStyle, ns.Prompt) end\n",
   "a change of the display in a fight is forgotten, not kept for the fight's end",
   expect="UI_SCALE_CHANGED in a fight waits for the fight's end")

_m("Core.lua",
   "function addon:TickBody()\n\tlocal now = GetTime()\n",
   "function addon:TickBody()\n\tif ns.Prompt then ns.Prompt:ApplyStyle() end\n\tlocal now = GetTime()\n",
   "the scan styles the prompt again every time",
   expect="hunt40-layout: the scan does not style the prompt again")
