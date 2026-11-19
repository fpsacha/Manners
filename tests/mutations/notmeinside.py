# Mutations for Thorns, not on me in a dungeon or a raid (1.11.30): the switch
# buff.notMeInside holds a tankChoice buff off yourself inside a dungeon or a
# raid (Core.lua Castable, Queue.lua SelfBuff), its place in Who to buff and in
# the window, its repair and its export. Each is caught by the scenario in
# tests/scenarios/notmeinside.lua that names it.

S = "runscenarios.py"

HELD = "notmeinside: Only me and the switch keep Thorns off a healer inside a dungeon, not outside"
DEFAULT = "notmeinside: nothing chosen is the way it was, Only me reminds inside a dungeon"
SWITCH = "notmeinside: the switch is in Who to buff and sets only its own set"
PLACE = "notmeinside: the options window places it right under Offer to"
REPAIR = "notmeinside: the set is repaired and travels with a profile"

mutate("Core.lua",
       "\t\tif opts.notMeInside and buff.tankChoice and opts.notMeInside[buff.key] then return false end\n",
       "",
       "notmeinside: Castable ignores the set",
       expect=HELD, script=S)

mutate("Queue.lua",
       "\t\tnotMeInside = notMeInside,\n",
       "",
       "notmeinside: SelfBuff never hands the set on",
       expect=HELD, script=S)

mutate("Queue.lua",
       "and next(notMeInside) ~= nil and ns.InDungeon()\n",
       "and next(notMeInside) ~= nil\n",
       "notmeinside: held everywhere, not only in a dungeon or a raid",
       expect=HELD, script=S)

mutate("Core.lua",
       "\t\t\tnotMeInside = {},\n",
       "\t\t\tnotMeInside = { thorns = true },\n",
       "notmeinside: on by default",
       expect=DEFAULT, script=S)

mutate("Options/Who.lua",
       "B().notMeInside[buff.key] = value and true or nil",
       "local _ = value",
       "notmeinside: the switch sets nothing",
       expect=SWITCH, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.tankChoice then items[#items + 1] = { \"who.notMeInside_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "notmeinside: the window leaves the switch out",
       expect=PLACE, script=S)

mutate("Core.lua",
       "\tif type(profile.buff.notMeInside) ~= \"table\" then profile.buff.notMeInside = {} end\n",
       "",
       "notmeinside: a damaged set is left as it is",
       expect=REPAIR, script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.notMeInside\"\n",
       "",
       "notmeinside: the export leaves the set out",
       expect=REPAIR, script=S)

mutate("Options/Advanced.lua",
       "\"buff.tanksMe\", \"buff.notMeInside\",",
       "\"buff.tanksMe\",",
       "notmeinside: the reset leaves the set behind",
       expect="model: the reset puts", script=S)
