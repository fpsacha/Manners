# Mutations for naming a rank for a low-level target (Prompt/Macro.lua CastName,
# Core.lua LandingRank). Each is caught by the scenario in
# tests/scenarios/downrank.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Macro.lua",
       "\treturn STRATEGIES[StrategyFor(entry)](entry, ns.CastName(entry))\n",
       "\treturn STRATEGIES[StrategyFor(entry)](entry, ns.EntrySpellName(entry))\n",
       "downrank: the macro never names a rank",
       expect="downrank: level 30 gets rank 3", script=S)

mutate("Prompt/Macro.lua",
       "\t\tns.CastName(entry),\n\t\ttostring(entry.groupCast and entry.groupCast.spell),",
       "\t\tns.EntrySpellName(entry),\n\t\ttostring(entry.groupCast and entry.groupCast.spell),",
       "downrank: a change of level does not rebuild the macro",
       expect="downrank: a change of level rebuilds the macro", script=S)

mutate("Prompt/Macro.lua",
       "\t\tif not id or id == top then return name end\n",
       "\t\tif not id then return name end\n",
       "downrank: the top rank is named too",
       expect="downrank: somebody of level 60 keeps the plain name", script=S)

mutate("Prompt/Macro.lua",
       "\t\tif type(level) ~= \"number\" or level < 1 then return name end\n",
       "\t\tif type(level) ~= \"number\" then return name end\n",
       "downrank: a skull is read as level -1",
       expect="downrank: a skull keeps the plain name", script=S)

mutate("Prompt/Macro.lua",
       "\t\tlocal level = ns.plain(_G.UnitLevel(unit))\n\t\tif type(level) ~= \"number\" or level < 1 then return name end\n",
       "\t\tlocal level = _G.UnitLevel(unit)\n\t\tif level == nil or level < 1 then return name end\n",
       "downrank: a secret level is not set aside",
       expect="downrank: a level the client will not say keeps the plain name", script=S)

mutate("Prompt/Macro.lua",
       "\t\treturn text and (name .. \"(\" .. text .. \")\") or name\n",
       "\t\treturn name .. \"(\" .. tostring(text) .. \")\"\n",
       "downrank: a rank with no text from the client is named anyway",
       expect="downrank: no rank text from the client keeps the plain name", script=S)
