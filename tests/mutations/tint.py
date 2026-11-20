# Mutations for a druid's name on the softer looks: it is softened no further
# than 0.35 (not on Luxe), and nobody else is. Each is caught by the scenario
# in tests/scenarios/tint.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Paint.lua",
       "\t\tif entry.class == \"DRUID\" and share > DRUID_SOFTEN and not S.activeLook.classTintOnly then share = DRUID_SOFTEN end\n",
       "",
       "tint: the druid softened as every class",
       expect="tint: a druid's name stays orange", script=S)

mutate("Prompt/Paint.lua",
       "entry.class == \"DRUID\" and share",
       "entry.class and share",
       "tint: every class softened as the druid",
       expect="tint: a warrior and a mage keep", script=S)

mutate("Looks/Luxe.lua",
       "\tclassTintOnly = true,\n",
       "",
       "tint: Luxe's druid taken off white",
       expect="tint: Luxe keeps", script=S)
