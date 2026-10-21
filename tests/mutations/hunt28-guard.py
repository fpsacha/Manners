# A guarded failure is handed on to the game's error handler, once per kind,
# so an error addon sees it (Core.lua, ns.Guard). Each fault put back is
# caught by the scenario in tests/scenarios/hunt28-guard.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif type(handler) == \"function\" then pcall(handler, \"Manners: \" .. label .. \": \" .. err) end\n",
       "",
       "hunt28-guard: a failure kept from the game's error handler",
       expect="hunt28-guard: a failure reaches the game's error handler once per kind",
       script=S)

mutate("Core.lua",
       "pcall(handler, \"Manners: \" .. label .. \": \" .. err)",
       "handler(\"Manners: \" .. label .. \": \" .. err)",
       "hunt28-guard: a broken error handler breaks the guard",
       expect="hunt28-guard: a failure reaches the game's error handler once per kind",
       script=S)

mutate("Core.lua",
       "\t\tif type(handler) == \"function\" then pcall(handler, \"Manners: \" .. label .. \": \" .. err) end\n",
       "\t\tif type(handler) == \"function\" then pcall(handler, \"Manners: \" .. label) end\n",
       "hunt28-guard: the error handler not told what broke",
       expect="hunt28-guard: a failure reaches the game's error handler once per kind",
       script=S)
