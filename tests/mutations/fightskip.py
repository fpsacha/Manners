# Skip players in a fight (filters.skipFighting): tests/scenarios/fightskip.lua.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif f.skipFighting == true and not pointed and type(_G.UnitAffectingCombat) == \"function\"\n",
       "\t\tif not pointed and type(_G.UnitAffectingCombat) == \"function\"\n",
       "fightskip: the switch ignored",
       expect="a passer-by in a fight was held back with the switch off", script=S)

mutate("Queue.lua",
       "\t\t\tand plain(_G.UnitAffectingCombat(owner or unit)) == true then\n",
       "\t\t\tand plain(_G.UnitAffectingCombat(owner or unit)) == \"never\" then\n",
       "fightskip: nobody held back",
       expect="fightskip: a passer-by in a fight is left alone only with the switch on", script=S)

mutate("Queue.lua",
       "\t\tif f.skipFighting == true and not pointed and type(_G.UnitAffectingCombat) == \"function\"\n",
       "\t\tif f.skipFighting == true and type(_G.UnitAffectingCombat) == \"function\"\n",
       "fightskip: the target held back too",
       expect="your target in a fight was held back", script=S)

mutate("Queue.lua",
       "\t\t\tand plain(_G.UnitAffectingCombat(owner or unit)) == true then\n"
       "\t\t\trejected[full] = true\n",
       "\t\t\tand plain(_G.UnitAffectingCombat(owner or unit)) == true then\n",
       "fightskip: no verdict, so memory offers them",
       expect="fightskip: a passer-by in a fight is left alone only with the switch on", script=S)

mutate("Core.lua",
       "\t\t\tskipFighting = false,\n",
       "\t\t\tskipFighting = true,\n",
       "fightskip: on by default",
       expect="Skip players in a fight is not off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\tskipFighting = {\n",
       "\t\t\tskipFightingGone = {\n",
       "fightskip: no control",
       expect="fightskip: the switch is on Who to skip", script=S)
