# Mutations for the drink's edges: tests/scenarios/moments-drink-edges.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\tif absent and slot.auraSeen then slot.castAt, slot.auraSeen = nil, nil end\n',
       '\t\tif absent then slot.castAt, slot.auraSeen = nil, nil end\n',
       "moments-drink-edges: a plain absence ends the drink's clock before its aura was ever seen",
       expect="moments-drink-edges: the cast comes before the aura", script=S)

mutate(SENSE,
       '\t\tif slot.drinkCast and type(auras.GetPlayerAuraBySpellID) == "function" then\n',
       '\t\tif false then\n',
       "moments-drink-edges: the aura of the cast's own spell is never read",
       expect="moments-drink-edges: a conjured refreshment has an aura", script=S)

mutate(M,
       '\t\t\t\tcalm.castAt, calm.drinkCast, calm.auraSeen = now, id, nil\n',
       '\t\t\t\tcalm.castAt, calm.drinkCast = now, id\n',
       "moments-drink-edges: a new clock keeps the last drink's aura as seen",
       expect="moments-drink-edges: the cast comes before the aura", script=S)

mutate(M,
       '\tif slot.row.calm then\n\t\tslot.openUntil = nil\n',
       '\tif false then\n\t\tslot.openUntil = nil\n',
       "moments-drink-edges: a press of the drink leaves the cover open",
       expect="moments-drink-edges: hidden mana: two clicks drink once", script=S)

mutate(M,
       '\t-- or a click on the world, never the first of two.\n\tif mouse ~= "LeftButton" then return end\n',
       '\t-- or a click on the world, never the first of two.\n',
       "moments-drink-edges: the cover opens on any mouse button",
       expect="moments-drink-edges: the cover is the left button's alone", script=S)

mutate(M,
       '\t\tcover:SetPassThroughButtons("RightButton", "MiddleButton", "Button4", "Button5")\n',
       '',
       "moments-drink-edges: the cover takes the right and middle buttons",
       expect="moments-drink-edges: the cover is the left button's alone", script=S)

mutate(M,
       '\t\tbutton:SetPassThroughButtons("RightButton", "MiddleButton", "Button4", "Button5")\n',
       '',
       "moments-drink-edges: the button takes the right and middle buttons",
       expect="moments-drink-edges: the cover is the left button's alone", script=S)

mutate(M,
       '\t\tif event == "PLAYER_LEVEL_UP" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then\n',
       '\t\tif false then\n',
       "moments-drink-edges: a level-up or a rising does not recount the bags",
       expect="moments-drink-edges: a level-up lights", script=S)

mutate(M,
       '\tPeaceSet("PLAYER_LEVEL_UP", pickInputs)\n',
       '\tPeaceSet("PLAYER_LEVEL_UP", false)\n',
       "moments-drink-edges: the level-up is not heard",
       expect="moments-drink-edges: a level-up lights", script=S)

mutate(M,
       '\tPeaceSet("PLAYER_ALIVE", pickInputs)\n',
       '\tPeaceSet("PLAYER_ALIVE", mana)\n',
       "moments-drink-edges: the rising is heard only while a drink is picked",
       expect="moments-drink-edges: dead at the release and alive again lights the drink (alive)", script=S)

mutate(M,
       '\tPeaceSet("PLAYER_UNGHOST", pickInputs)\n',
       '\tPeaceSet("PLAYER_UNGHOST", mana)\n',
       "moments-drink-edges: the ghost rising is heard only while a drink is picked",
       expect="moments-drink-edges: dead at the release and alive again lights the drink (unghost)", script=S)
