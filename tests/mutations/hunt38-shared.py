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

# The shared line setter honours the flag for the name and the list (Leather's
# own mutation holds the name; this holds the list, and Ribbon's, as well).
_m("Prompt/Text.lua",
   "if not ink.light and look and (look.inkOnDark or (fs == R.subText and look.subOnDark)) then",
   "if not ink.light and look and (fs == R.subText and look.subOnDark) then",
   "the line setter ignores a look's own dark ground for the name and the list",
   expect="hunt38-shared: leather writes the same ink")
