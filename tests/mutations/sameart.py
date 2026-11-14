# Mutations for H.sameArt (tests/scenarios.lua): the comparison the generators'
# output is held to against the textures that ship. Caught by
# tests/scenarios/sameart.lua.

S = "runscenarios.py"

mutate("tests/scenarios.lua",
       "\t\t\t\tif d > 1 or d < -1 then return false end\n",
       "\t\t\t\tif d > 2 or d < -2 then return false end\n",
       "sameart: two steps off is let through",
       expect="two steps up is the same art", script=S)

mutate("tests/scenarios.lua",
       "\t\t\t\tif d > 1 or d < -1 then return false end\n",
       "\t\t\t\tif d > 1 then return false end\n",
       "sameart: any step up is let through",
       expect="two steps up is the same art", script=S)

mutate("tests/scenarios.lua",
       "\t\t\t\tif d > 1 or d < -1 then return false end\n",
       "\t\t\t\tif d < -1 then return false end\n",
       "sameart: any step down is let through",
       expect="two steps down is the same art", script=S)

mutate("tests/scenarios.lua",
       "\tif type(one) ~= \"string\" or type(two) ~= \"string\" or #one ~= #two then return false end\n",
       "\tif type(one) ~= \"string\" or type(two) ~= \"string\" then return false end\n",
       "sameart: a longer file is let through",
       expect="a longer file is the same art", script=S)

mutate("tests/scenarios.lua",
       "\tif one:sub(1, 18) ~= two:sub(1, 18) then return false end\n",
       "",
       "sameart: another size of picture is let through",
       expect="a file of another width is the same art", script=S)

mutate("tests/scenarios.lua",
       "\tif one == two then return true end\n\tif type(one) ~= \"string\"",
       "\tif true then return true end\n\tif type(one) ~= \"string\"",
       "sameart: everything is the same art",
       expect="sameart: one step off is the same art", script=S)
