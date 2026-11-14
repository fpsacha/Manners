# Mutations for the second review of the newer looks (Looks/Warchief.lua,
# Looks/Gearworks.lua). Each undoes one fix and is caught by the scenario in
# tests/scenarios/looks-new-review2.lua that names it.

S = "runscenarios.py"

EMBERS = "still rise from the crest"
WORKS = "with the prompt down the works still run"
BREATH_OFF = "with the prompt up and the breath off, the works stand still"
W_MEASURE = "Warchief measured the name"
G_MEASURE = "Gearworks measured the name"

MEMO = ("\t\tif secret or text ~= self.measuredText or size ~= self.measuredSize then\n"
        "\t\t\tself.measuredWidth = kit.TextWidth(kit.name)\n")
EVERY = ("\t\tif true then\n"
         "\t\t\tself.measuredWidth = kit.TextWidth(kit.name)\n")

# Calm stops the three lights of the breath and leaves the embers looping.
mutate("Looks/Warchief.lua",
       "\t\t\tStopAll(self.pulse)\n"
       "\t\t\t-- Calm chosen while it breathed: the embers stop with the\n"
       "\t\t\t-- breath, which alone had sent them up.\n"
       "\t\t\tStopAll(self.rise)\n",
       "\t\t\tStopAll(self.pulse)\n",
       "looks-new-review2: Warchief's embers outlive a breath Calm ended",
       expect=EMBERS, script=S)

# The prompt taken down leaves the cogs, the glint and the bubbles running.
mutate("Looks/Gearworks.lua",
       "\tself.calmLit = nil\n"
       "\t-- The prompt taken down ends here and nowhere else of the look's: the\n"
       "\t-- cogs, the glint and the bubbles stop under a hidden panel.\n"
       "\tself:Idle()\n",
       "\tself.calmLit = nil\n",
       "looks-new-review2: Gearworks' works run on under a hidden prompt",
       expect=WORKS, script=S)

# The works stopped whenever the breath is, the prompt up or not.
mutate("Looks/Gearworks.lua",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()\n"
       "\tlocal cogs = on and self.boxed and not self.jammed\n",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()\n"
       "\ton = on and self.pulse[1]:IsPlaying()\n"
       "\tlocal cogs = on and self.boxed and not self.jammed\n",
       "looks-new-review2: Gearworks' works stop with the breath",
       expect=BREATH_OFF, script=S)

# A name at its smallest measured at every paint of the scan.
mutate("Looks/Warchief.lua", MEMO, EVERY,
       "looks-new-review2: Warchief measures a name at its smallest at every scan",
       expect=W_MEASURE, script=S)

mutate("Looks/Gearworks.lua", MEMO, EVERY,
       "looks-new-review2: Gearworks measures a name at its smallest at every scan",
       expect=G_MEASURE, script=S)
