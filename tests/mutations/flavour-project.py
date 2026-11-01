# Forever's own project id, WOW_PROJECT_CAMELOT (Flavour.lua, BY_PROJECT), and
# its place over an interface number outside Forever's band. Each fault put
# back has to be caught by the scenario in tests/scenarios/flavour-project.lua
# that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The constant forgotten: a Forever on a 2.x number reads as Burning Crusade.
mutate("Flavour.lua",
       "\t{ constant = \"WOW_PROJECT_CAMELOT\", flavour = \"camelot\", family = \"modern\", only = true },\n",
       "",
       "flavour-project: Forever's project id unknown",
       expect="flavour-project: a Forever on an interface number outside its band is still Forever", script=S)

# Known, but the interface band always wins.
mutate("Flavour.lua",
       "\tif overruled then band = { flavour = project.flavour, family = project.family } end\n",
       "",
       "flavour-project: the band wins over Forever's project id",
       expect="flavour-project: a Forever on an interface number outside its band is still Forever", script=S)

# Every project id trusted over the band, retail's MAINLINE included.
mutate("Flavour.lua",
       "\tlocal overruled = project and project.only and not (band and band.flavour == project.flavour)\n",
       "\tlocal overruled = project and not (band and band.flavour == project.flavour)\n",
       "flavour-project: a family-only project id trusted over the band",
       expect="flavour-project: retail with the constant defined is still retail", script=S)
