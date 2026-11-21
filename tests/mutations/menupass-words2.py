# Mutations for plain English, part 2: tests/scenarios/menupass-words2.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Launcher.lua",
       "\tlocal effects = parent:CreateButton(L[\"Animations\"])\n",
       "\tlocal effects = parent:CreateButton(L[\"Effects\"])\n",
       "menupass-words2: the launcher calls Animations Effects again",
       expect="menupass-words2: the launcher uses the window's words", script=S)

mutate("Prompt/Press.lua",
       'left alone: %s (%s)."]',
       'left alone: %s, on the %s tab."]',
       "menupass-words2: the press line calls a page a tab again",
       expect="menupass-words2: no line calls a page a tab", script=S)

mutate("Options/Who.lua",
       "L[\"Off: nobody is asked while you are in a city or an inn.\"]",
       "L[\"Off: nobody is asked while the game calls you resting, in a city or an inn.\"]",
       "menupass-words2: a tooltip says the game calls you resting again",
       expect="menupass-words2: no tooltip says the game calls you resting", script=S)
