# Mutations for Spellsteal for the moment: tests/scenarios/moments-spellsteal.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\t\t\t\tif plain(rawSteal) == true then return "yes" end\n',
       '',
       "moments-spellsteal: a plain flag read through the id list is ignored",
       expect="moments-spellsteal: the index read hidden but the id list and the records plain", script=S)

mutate(SENSE,
       '\t\tif CanPaint("any") then\n',
       '\t\tif false then\n',
       "moments-spellsteal: the hidden flags are not handed to the game",
       expect="moments-spellsteal: withheld: the hidden flags are ORed by the game", script=S)

mutate(SENSE,
       '\t\t\tif type(rawSteal) == "boolean" then\n\t\t\t\tif issecretvalue(rawSteal) then\n',
       '\t\t\tif true then\n\t\t\t\tif issecretvalue(rawSteal) then\n',
       "moments-spellsteal: a hidden nil flag is held like a boolean",
       expect="moments-spellsteal: withheld: a hidden nil flag is skipped", script=S)

mutate("Prompt/MomentsData.lua",
       '\t\tRow { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true, guard = "twice",\n',
       '\t\tRow { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true,\n',
       "moments-spellsteal: a game-painted Spellsteal takes two clicks",
       expect="moments-spellsteal: withheld: the hidden flags are ORed by the game", script=S)

mutate(SENSE,
       '\tif #ids == 0 then return "no", "your target has no buffs" end\n',
       '',
       "moments-spellsteal: a target with no buffs is not refused",
       expect="moments-spellsteal: plain: no buffs at all is dark and says so", script=S)
