# Mutations for hunt 38 on the Leather look: tests/scenarios/hunt38-leather.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each undoes one fix and names
# the scenario that has to go red.

LEATHER = "Looks/Leather.lua"
S = "runscenarios.py"

S_ONCE = 'hunt38-leather: on Calm with the flash on once, a favour\'s soft glow plays out'


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only hunt38-leather finds them all."""
    kw.setdefault("script", S)
    mutate(file, old, new, "hunt38-leather: " + label, **kw)


_m(LEATHER,
   "\t\tself.glowGen = (self.glowGen or 0) + 1\n\t\tself:HoldPulse()\n\t\treturn\n\tend\n\tif not full or self.glowSpent then",
   "\t\tself:StopAttention()\n\t\treturn\n\tend\n\tif not full or self.glowSpent then",
   "a flash set to once stops the soft fade it has just played on Calm",
   expect=S_ONCE)
