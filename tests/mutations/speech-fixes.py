# Mutations for the "In character" fixes of round 30: the Haranir by the race
# file the client returns, like for like judged by the buff, the warlock's
# water lines kept to Unending Breath, and RP.ONTO kept to a manaOnly spell.
# Each is caught by the scenario in tests/scenarios/speech-fixes.lua that
# names it.

# The Haranir keyed by their name rather than the client's race file.
mutate("Phrases.lua",
       '\tHarronir = "haranir",\n',
       '\tHaranir = "haranir",\n',
       "speech-fix haranir keyed by name",
       expect="speech-fix: a Haranir (race file Harronir) speaks as the Haranir",
       script="runscenarios.py")

# Like for like by name only: a Prayer of Fortitude answered with Fortitude
# is a trade again.
mutate("Phrases.lua",
       "\t\tif gift ~= nil and (gift == single or (key and RP.GiftKey(entry) == key)) then gift = nil end\n",
       "\t\tif gift ~= nil and gift == single then gift = nil end\n",
       "speech-fix group favour traded for itself",
       expect="speech-fix: a favour given as the group version is no trade for the same buff",
       script="runscenarios.py")

# A class's lines about one of its spells said with any spell.
mutate("Phrases.lua",
       "\t\t\t\t\tand (about[text] == nil or about[text] == key)\n",
       "",
       "speech-fix warlock water with dark intent",
       expect="speech-fix: a Mists warlock giving Dark Intent says nothing about water",
       script="runscenarios.py")

# ...and kept from the spell they are about.
mutate("Phrases.lua",
       "\t\t\t\t\tand (about[text] == nil or about[text] == key)\n",
       "\t\t\t\t\tand about[text] == nil\n",
       "speech-fix warlock water never said",
       expect="speech-fix: a Mists warlock giving Dark Intent says nothing about water",
       script="runscenarios.py")

# RP.ONTO joined by key alone, manaOnly or not.
mutate("Phrases.lua",
       "\t\tlocal onto = key and entry.buff.manaOnly and RP.ONTO[key]\n",
       "\t\tlocal onto = key and RP.ONTO[key]\n",
       "speech-fix onto for a buff everybody uses",
       expect="speech-fix: Arcane Brilliance on Mists is not called useless to a warrior",
       script="runscenarios.py")
