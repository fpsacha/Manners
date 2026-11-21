# Mutations for the options window's search words:
# tests/scenarios/menupass-search.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/Search.lua",
       "\tif AtWordStart(entry.label, query) then return 0 end\n",
       "\tif Has(entry.label, query) then return 0 end\n",
       "menupass-search: a label matched inside a word ranks as one at its start",
       expect="menupass-search: a word at the start beats", script=S)

mutate("Options/Window/Search.lua",
       "local SPELLING = { color = \"colour\", gray = \"grey\", favor = \"favour\", center = \"centre\", behavior = \"behaviour\" }\n",
       "local SPELLING = {}\n",
       "menupass-search: no US spellings",
       expect="menupass-search: US spellings", script=S)

mutate("Options/Window/Search.lua",
       "function(entry) return Best(entry, query, folded) end, limit)\n",
       "function(entry) return Best(entry, folded, folded) end, limit)\n",
       "menupass-search: the query is ranked only folded",
       expect="menupass-search: US spellings", script=S)

mutate("Options/Window/Search.lua",
       "\tif #found > 0 or not find(query, \" \", 1, true) then return found end\n",
       "\tif true then return found end\n",
       "menupass-search: no phrase fallback",
       expect="menupass-search: filler words", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"appearance.breakFree\"] = L[\"wotf forsaken break free fear charm sleep fight button turn off hide\"],\n",
       "",
       "menupass-search: no search words for the break-free switch",
       expect="menupass-search: what players typed", script=S)
