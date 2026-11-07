# Mutations for bug hunt 35, the phrases area. Each is caught by the scenario
# in tests/scenarios/phrases-fixes.lua that names it.

# The line calling the person thanked alive back with the lines for kin.
mutate("Phrases.lua",
       '\t\t\tL["Thank you, {name}. Most people only cast on me to make me lie back down."],\n',
       '\t\t\tL["Thank you, {name}. Most people only cast on me to make me lie back down."],\n\t\t\tL["Warm, generous and alive, {name}. I can only match you on one. Here it is."],\n',
       "alive line said to kin",
       expect="phrases-fix: a Forsaken never calls another Forsaken alive",
       script="runscenarios.py")

# 'A gift for the dead' in a man's voice, said by a woman.
mutate("Phrases.lua",
       "\tfrFR = {\n\t\t[\"A gift for the dead, {name}? Most people bring flowers. Then they run.\"] = true,\n",
       "\tfrFR = {\n",
       "gift for the dead masculine in frFR",
       expect="phrases-fix: a female Forsaken is spared 'a gift for the dead' in frFR",
       script="runscenarios.py")
mutate("Phrases.lua",
       "\titIT = {\n\t\t[\"A gift for the dead, {name}? Most people bring flowers. Then they run.\"] = true,\n",
       "\titIT = {\n",
       "gift for the dead masculine in itIT",
       expect="phrases-fix: a female Forsaken is spared 'a gift for the dead' in itIT",
       script="runscenarios.py")
mutate("Phrases.lua",
       "\tesES = {\n\t\t[\"A gift for the dead, {name}? Most people bring flowers. Then they run.\"] = true,\n",
       "\tesES = {\n",
       "gift for the dead masculine in esES",
       expect="phrases-fix: a female Forsaken is spared 'a gift for the dead' in esES",
       script="runscenarios.py")
mutate("Phrases.lua",
       "\tptBR = {\n\t\t[\"A gift for the dead, {name}? Most people bring flowers. Then they run.\"] = true,\n",
       "\tptBR = {\n",
       "gift for the dead masculine in ptBR",
       expect="phrases-fix: a female Forsaken is spared 'a gift for the dead' in ptBR",
       script="runscenarios.py")

# 'gentil' to the Dark Lady, said by a woman.
mutate("Phrases.lua",
       "\t\t[\"Please don't tell the Dark Lady I was nice to somebody, {name}.\"] = true,\n",
       "",
       "gentil said by a woman",
       expect="phrases-fix: a female Forsaken in French is never 'gentil' to the Dark Lady",
       script="runscenarios.py")

# /party to a battleground teammate outside the premade.
mutate("Speech.lua",
       "\t\t\tif not found then return false end\n",
       "",
       "party line outside the premade",
       expect="phrases-fix: no party line to a battleground teammate outside your premade",
       script="runscenarios.py")
