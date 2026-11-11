# Mutations for "Classes I buff as passers-by" (filters.skipNearbyClasses).
# Each is caught by the scenario in tests/scenarios/classskip.lua that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif skipClasses and reason == \"nearby\" and not pointed\n",
       "\t\tif false and skipClasses and reason == \"nearby\" and not pointed\n",
       "classskip: the walk never leaves a class out",
       expect="classskip: a passer-by of an unticked class is left out, others are not", script=S)

mutate("Queue.lua",
       "\t\tif skipClasses and reason == \"nearby\" and not pointed\n",
       "\t\tif skipClasses and (reason == \"nearby\" or reason == \"group\") and not pointed\n",
       "classskip: the group is held to it too",
       expect="classskip: your group and your target of that class are still offered", script=S)

mutate("Queue.lua",
       "\t\tif skipClasses and reason == \"nearby\" and not pointed\n",
       "\t\tif skipClasses and reason == \"nearby\"\n",
       "classskip: the target is held to it too",
       expect="classskip: your group and your target of that class are still offered", script=S)

mutate("Queue.lua",
       "\t\tif skipClasses and reason == \"nearby\" and not pointed\n",
       "\t\tif skipClasses and reason ~= \"group\" and not pointed\n",
       "classskip: a favour owed is held to it too",
       expect="classskip: somebody of that class who buffed you is still offered", script=S)

mutate("Queue.lua",
       "\t\t\tand skipClasses[plain(select(2, UnitClass(unit))) or \"\"] then\n",
       "\t\t\tand not skipClasses[plain(select(2, UnitClass(unit))) or \"\"] then\n",
       "classskip: the ticked classes are the ones left out",
       expect="classskip: a passer-by of an unticked class is left out, others are not", script=S)

mutate("Queue.lua",
       "\t\t\tor (nearby and skipClasses and memo.class and skipClasses[memo.class])\n",
       "",
       "classskip: a passer-by remembered keeps being offered",
       expect="classskip: a passer-by remembered is let go when the class is unticked", script=S)

mutate("Queue.lua",
       "\t\tif type(set) ~= \"table\" or next(set) == nil then return nil end\n",
       "\t\tdo return nil end\n",
       "classskip: the set is never read",
       expect="classskip: a passer-by of an unticked class is left out, others are not", script=S)

mutate("Core.lua",
       "\t\t\tskipNearbyClasses = {},\n",
       "\t\t\tskipNearbyClasses = { WARRIOR = true },\n",
       "classskip: a class is left out by default",
       expect="classskip: every class is offered in a new profile", script=S)

mutate("Core.lua",
       "\t\tif type(class) ~= \"string\" or not class:find(\"^%u+$\") or flag ~= true then skipClasses[class] = nil end\n",
       "",
       "classskip: a damaged set is never repaired",
       expect="classskip: a damaged set is repaired and the set travels with a profile", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"filters.skipNearbyClasses\" then\n",
       "\t\t\t\t\t\t\tor false then\n",
       "classskip: the set does not travel with a profile",
       expect="classskip: a damaged set is repaired and the set travels with a profile", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tget = function(_, class) return F().skipNearbyClasses[class] ~= true end,\n",
       "\t\t\t\tget = function(_, class) return F().skipNearbyClasses[class] == true end,\n",
       "classskip: the grid shows the classes left out as ticked",
       expect="classskip: the grid lists the client's classes, ticked, and unticking stores it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tF().skipNearbyClasses[class] = (not on) or nil\n",
       "\t\t\t\t\tF().skipNearbyClasses[class] = on or nil\n",
       "classskip: unticking stores the class as offered",
       expect="classskip: the grid lists the client's classes, ticked, and unticking stores it", script=S)

mutate("Options/Who.lua",
       "\tfor _, class in ipairs(CLASSES_BY_FLAVOUR[flavour] or {}) do values[class] = ns.ClassName(class) end\n",
       "\tfor _, class in ipairs(CLASSES_BY_FLAVOUR.mainline) do values[class] = ns.ClassName(class) end\n",
       "classskip: every client lists retail's classes",
       expect="classskip: the grid lists the client's classes, ticked, and unticking stores it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tvalues = ClassChoices,\n\t\t\t\tdisabled = function() return not S().strangers end,\n",
       "\t\t\t\tvalues = ClassChoices,\n",
       "classskip: the grid is never greyed",
       expect="classskip: the grid lists the client's classes, ticked, and unticking stores it", script=S)
