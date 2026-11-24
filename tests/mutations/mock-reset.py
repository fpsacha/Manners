# Mutations for what Mock.reset lets go of (tests/mockwidgets.lua, install):
# tests/scenarios/mock-reset.lua.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"

# The children listed on UIParent and GameTooltip kept from one reset to the
# next: every frame of every addon the run loaded, held until the run ends.
mutate("tests/mockwidgets.lua",
       "\t\tif type(root) == \"table\" then root._kids = nil end\n",
       "",
       "mock-reset: UIParent keeps its children across a reset",
       expect="mock-reset: a reset keeps none of the frames made before it", script=S)
