# Mutations for the race voices of the "In character" set: a thank-you in the
# speaker's people's voice, and the favours Manners never offers thanked for
# what they do. Each is caught by the scenario in
# tests/scenarios/race-voice.lua that names it.

# The people's lines weighed as they were before the race-voice pass: a
# thank-you is the people's own about three times in ten.
mutate("Phrases.lua",
       "\trace = 36, kin = 12,",
       "\trace = 9, kin = 12,",
       "race voice weighed as before",
       expect="race-voice: a thank-you sounds like the speaker's people",
       script="runscenarios.py")

# The people's pool drawn at a quarter of its weight, in RP.Pick itself.
mutate("Phrases.lua",
       '\t\t\tadd(Both(own, outsider and outsider[kind]), weight.race, "race")\n',
       '\t\t\tadd(Both(own, outsider and outsider[kind]), weight.race / 4, "race")\n',
       "race pool at a quarter weight",
       expect="race-voice: a Forsaken's thank-you draws Forsaken lines",
       script="runscenarios.py")

# The trade lines weighed above what a gift does.
mutate("Phrases.lua",
       "\tspell = 3, trade = 2, gift = 3,",
       "\tspell = 3, trade = 3, gift = 2,",
       "trade lines above gift lines",
       expect="race-voice: a favour-only gift is thanked for what it does",
       script="runscenarios.py")

# A Soulstone, Fear Ward, Water Walking or Detect Invisibility never found:
# no buff holds them, and the lookup by id is gone.
mutate("Phrases.lua",
       "\t\t\tkey = type(buff) == \"table\" and buff.key or (id and FAVOUR_KEY[id]) or nil\n",
       "\t\t\tkey = type(buff) == \"table\" and buff.key or nil\n",
       "favour-only gifts have no gift lines",
       expect="race-voice: a favour-only gift is thanked for what it does",
       script="runscenarios.py")

# The gift lines of the favours filed under a name nothing asks for.
mutate("Phrases.lua",
       '\t\t[6346] = "fearward", [546] = "waterwalking",\n',
       '\t\t[6346] = "fear", [546] = "waterwalking",\n',
       "fear ward gift key misspelt",
       expect="race-voice: a favour-only gift is thanked for what it does",
       script="runscenarios.py")
