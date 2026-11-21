# Mutations for the changed marks and the What I changed list:
# tests/scenarios/menupass-changed.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/WindowPage.lua",
       "\tif want == nil then return false end\n\treturn not Same(have, want, item.def.step)\n",
       "\tif want == nil then return false end\n\treturn false\n",
       "menupass-changed: UI.IsChanged returns false",
       expect="menupass-changed: a changed switch, slider and choice are marked", script=S)

mutate("Options/Window/Widgets.lua",
       "\telse\n\t\tW.Commit(row, want)\n\tend\n\tif ns.RefreshOptionsDisplay",
       "\telse\n\t\tns.db.profile.timing.skipSeconds = want\n\tend\n\tif ns.RefreshOptionsDisplay",
       "menupass-changed: the mark writes the profile field directly",
       expect="menupass-changed: the mark puts one setting back through its own setter", script=S)

mutate("Options/Window/WindowSearch.lua",
       "\t\tlocal own = hit.ref.via or hit.ref.path\n\t\tlocal item = own",
       "\t\tlocal own = hit.ref.path\n\t\tlocal item = own",
       "menupass-changed: ShowChanged filters on ref.path only",
       expect="menupass-changed: What I changed lists", script=S)
