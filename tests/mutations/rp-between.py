# The box of the releases between the two rewordings of the examples
# (RP.BETWEEN) left out of the boxes the examples have been.
S = "runscenarios.py"

mutate("Phrases.lua",
       "\tSAVED[2], SAVED[3], SAVED[4] = { false, RP.BETWEEN }, SAVED[2], SAVED[3]\n",
       "",
       "rp-between: the box between the rewordings forgotten",
       expect="a troll mage's 1.11.25 box counts as edited", script=S)

# The two lists chained the other way round: a line reworded twice reads as it
# did after the first rewording in the oldest boxes.
mutate("Phrases.lua",
       "\t\twas[pair[1]] = was[pair[2]] or pair[2]\n",
       "\t\twas[pair[1]] = pair[2]\n",
       "rp-between: a line reworded twice not followed back",
       expect="a box of lines reworded since still counts", script=S)

# The box between built from today's lines.
mutate("Phrases.lua",
       "\t\tRP.BETWEEN[name] = Recent(RP[name])\n",
       "\t\tRP.BETWEEN[name] = RP[name]\n",
       "rp-between: the box between built from today's lines",
       expect="a troll mage's 1.11.25 box counts as edited", script=S)
