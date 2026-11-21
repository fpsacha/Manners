# Mutations for the pointers package: text that names a page asks the window's
# layout for it (tests/scenarios/menupass-pointers.lua, and the fight buttons'
# hovers in fightbuttons.lua, curefight.lua and supplies.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Shared.lua",
       "\tif TITLE[id] then return TITLE[id]() end\n",
       "\tif TITLE[id] then return L[\"Who to buff\"] end\n",
       "menupass-pointers: TabOf answers one page whatever it finds",
       expect="menupass-pointers: a page name follows its control", script=S)

mutate("Options/Launcher.lua",
       "Page.TabOf(\"when.hideMounted\") or \"\"), 1, 0.82, 0, true, nil, \"mounted\"\n\t\tend\n\t\tif ownOnly",
       "L[\"When to offer\"]), 1, 0.82, 0, true, nil, \"mounted\"\n\t\tend\n\t\tif ownOnly",
       "menupass-pointers: the mounted line names its page by hand",
       expect="menupass-pointers: no sentence names a page by hand", script=S)

mutate("Prompt/BreakFree.lua",
       "\tns.AddSettingsLine(tip, \"appearance.breakFree\")\n",
       "",
       "menupass-pointers: the break-free tooltip does not say where its settings are",
       expect="menupass-pointers: the fight buttons say where", script=S)
