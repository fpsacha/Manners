# Mutations for Asking for a buff on What I say and Who to buff's fine print fold:
# tests/scenarios/menupass-say.lua.
#
# Run by tests/selftest.py with mutate() in scenario scope. Each puts one rule
# back and names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/Layout.lua",
       "{ key = \"who.castFine\", title = L[\"Other people's buffs\"], fold = true, items = FineItems() },",
       "{ key = \"who.castFine\", title = L[\"Other people's buffs\"], fold = true, items = {} },\n"
       "\t\t\t\t{ key = \"who.castLeft\", items = FineItems() },",
       "menupass-say: the fine print goes back out of the fold",
       expect="menupass-say: Who to buff's fine print", script=S)

mutate("Options/Window/WindowPage.lua",
       "\t[\"who.spareFishBowl\"] = { { \"buff\", \"spareFishBowl\" } },\n",
       "",
       "menupass-say: the Fish Bowl switch does not light the fold's dot",
       expect="menupass-say: Who to buff's fine print", script=S)

mutate("Options/Advanced.lua",
       "if path == \"sources.ask\" or path:find(\"^ask%.\") then return false end",
       "if path == \"sources.ask\" or path == \"ask.line\" or path == \"ask.inTowns\" or path == \"ask.own\" then return false end\n\t\t\tif path == \"ask.channel\" then return true end",
       "menupass-say: a rogue's reset keeps the ask channel",
       expect="menupass-say: What I say's reset", script=S)

mutate("Options/Window/Layout.lua",
       "{ key = \"click.asking\", title = L[\"Asking for a buff\"], home = true, items = {",
       "{ key = \"who.asking\", title = L[\"Asking for a buff\"], home = true, items = {",
       "menupass-say: the asking section moves back to who",
       expect="menupass-say: asking for a buff is on What I say", script=S)
