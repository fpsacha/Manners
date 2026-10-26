# Mutations for hunt 38's finds in the code the looks share:
# tests/scenarios/hunt38-shared.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back the mistake
# the hunt fixed and names the scenario that has to object.


def _m(file, old, new, label, **kw):
    kw.setdefault("script", "runscenarios.py")
    mutate(file, old, new, "hunt38-shared: " + label, **kw)


# --- a look on a ground of its own says so ----------------------------------

_m("Looks/Ribbon.lua",
   "\tsubOnDark = true,\n\tinkOnDark = true,\n",
   "\tsubOnDark = true,\n",
   "Ribbon leaves its name and its list to a pale panel colour's legibility",
   expect="hunt38-shared: ribbon writes the same ink")

# --- a toggle that does nothing is greyed ------------------------------------

_m("Options/Look.lua",
   "local ROUND_ALWAYS = { letter = true, ribbon = true, toast = true }",
   "local ROUND_ALWAYS = { letter = true }",
   "the round icon toggle live on the Ribbon's and the Toast's medallions",
   expect="hunt38-shared: the round icon toggle is off where the icon is always round")

# --- the chip is judged by the room this count needs ---------------------------

_m("Prompt/Text.lua",
   "\tif S.activeLook then on = S.activeLook:Chip(on) and true or false end\n"
   "\t-- No chip over a name with no room left beside it, on any look.\n"
   "\tif on and fit.width - fit.textX - fit.chipRoom < MIN_ROOM then\n"
   "\t\ton = false\n"
   "\t\tR.countText:SetText(\"\")\n"
   "\t\tif S.activeLook then S.activeLook:Chip(false) end\n"
   "\tend\n"
   "\tif not S.activeLook then R.countChip:SetShown(on) end\n",
   "\t-- No chip over a name with no room left beside it, on any look.\n"
   "\tif on and fit.width - fit.textX - fit.chipRoom < MIN_ROOM then\n"
   "\t\ton = false\n"
   "\t\tR.countText:SetText(\"\")\n"
   "\tend\n"
   "\tif S.activeLook then\n"
   "\t\ton = S.activeLook:Chip(on) and true or false\n"
   "\telse\n"
   "\t\tR.countChip:SetShown(on)\n"
   "\tend\n",
   "the room check reads the last count's room before the look has worked out this one's",
   expect="hunt38-shared: a one-digit count has its chip after a three-digit one")

# The shared line setter honours the flag for the name and the list (Leather's
# own mutation holds the name; this holds the list, and Ribbon's, as well).
_m("Prompt/Text.lua",
   "if not ink.light and look and (look.inkOnDark or (fs == R.subText and look.subOnDark)) then",
   "if not ink.light and look and (fs == R.subText and look.subOnDark) then",
   "the line setter ignores a look's own dark ground for the name and the list",
   expect="hunt38-shared: leather writes the same ink")
