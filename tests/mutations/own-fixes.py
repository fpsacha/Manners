# Mutations for tests/scenarios/own-fixes.lua (bug hunt 39, own buffs): each
# puts back one fault the round fixed, and the scenario of that name has to
# catch it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "own-fix: "

# A healthstone whose name ends in its own bracket: the /cast line names it
# bare, and the macro reads "(Major)" as a rank.
mutate("Prompt/Macro.lua",
       "\t\tif type(name) == \"string\" and name:sub(-1) == \")\" and not (buff and buff.item) then return name .. \"()\" end\n",
       "",
       "own-fix: a bracketed own spell is cast without ()",
       expect=P + "a healthstone whose name ends in its own bracket is cast with () so the macro reads no rank", script=S)

# Food the game hides stays unread after a death in a battleground.
mutate("Core.lua",
       "\t\tif family.food then local up, spell, left = ReadWellFed(family, GetTime()) if up == nil and ns.GoneWithDeath(\"own:\" .. family.key, family.throughDeath) then return false end return up, spell, left end\n",
       "\t\tif family.food then return ReadWellFed(family, GetTime()) end\n",
       "own-fix: hidden Well Fed never gone with a death",
       expect=P + "after a death in a battleground food and an elixir the game hides read as gone", script=S)

# An elixir the game hides stays unread after a death in a battleground.
mutate("Core.lua",
       "\t\tif family.consumable then local up, spell, left = ReadConsumable(family, GetTime()) if up == nil and ns.GoneWithDeath(\"own:\" .. family.key, family.throughDeath) then return false end return up, spell, left end\n",
       "\t\tif family.consumable then return ReadConsumable(family, GetTime()) end\n",
       "own-fix: a hidden elixir never gone with a death",
       expect=P + "after a death in a battleground food and an elixir the game hides read as gone", script=S)

# A flask, which stays on through death, read as gone with it.
mutate("Buffs.lua",
       "\t\tif flask then flask.throughDeath = true end\n",
       "",
       "own-fix: a hidden flask read as gone with a death",
       expect=P + "after a death in a battleground food and an elixir the game hides read as gone", script=S)
