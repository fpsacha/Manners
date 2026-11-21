# Mutations for the line under each page's title: tests/scenarios/menupass-blurb.lua.
#
# Run by tests/selftest.py with mutate() in scenario scope. Each puts one rule
# back and names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/WindowPage.lua",
       "\tif m.page.blurb then\n",
       "\tif false then\n",
       "menupass-blurb: the line under the title is never drawn",
       expect="menupass-blurb: each page says what it is for", script=S)
