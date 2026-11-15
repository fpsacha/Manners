# A blessing for each class (tests/scenarios/forclass.lua).
S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tlocal first = not pinned and opts.theirClass and db.buff.forClass[opts.theirClass]\n",
       "\t\t\tlocal first = nil\n",
       "forclass: the class's blessing is never read",
       expect="a mage is offered the blessing chosen for mages, a rogue the order's", script=S)

mutate("Core.lua",
       "\t\t\tlocal first = not pinned and opts.theirClass and db.buff.forClass[opts.theirClass]\n",
       "\t\t\tlocal first = not pinned and db.buff.forClass.MAGE\n",
       "forclass: one class's blessing for every class",
       expect="a mage is offered the blessing chosen for mages, a rogue the order's", script=S)

mutate("Core.lua",
       "\t\t\t\t\tfor i = 1, #candidates do\n\t\t\t\t\t\tif i ~= at then CLASS_FIRST[#CLASS_FIRST + 1] = candidates[i] end\n\t\t\t\t\tend\n",
       "",
       "forclass: the class's blessing and nothing behind it",
       expect="the chosen blessing worn from another paladin is passed over for the order's", script=S)

mutate("Queue.lua",
       "\t\topts.theirClass = next(db.buff.forClass) ~= nil and not owner and plain(select(2, UnitClass(unit))) or nil\n",
       "\t\topts.theirClass = nil\n",
       "forclass: the walk is not told anybody's class",
       expect="a mage is offered the blessing chosen for mages, a rogue the order's", script=S)

mutate("Core.lua",
       "\t\t\tfixed(\"buff.forClass.\" .. tostring(class), key)\n\t\t\tprofile.buff.forClass[class] = nil\n",
       "",
       "forclass: a damaged class or key is kept",
       expect="forclass: the choice is repaired and travels with a profile", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\telseif name == \"buff.forClass\" then\n",
       "\t\t\t\t\t\telseif name == \"buff.forClass.\" then\n",
       "forclass: the choice does not travel with a profile",
       expect="forclass: the choice is repaired and travels with a profile", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().forClass[ClassPick()] = (value ~= \"auto\") and value or nil\n",
       "\t\t\t\t\tB().forClass[ClassPick()] = value\n",
       "forclass: Automatic kept as a blessing's key",
       expect="forclass: the page picks a class, gives it a blessing and clears them all", script=S)

mutate("Options/Who.lua",
       "\treturn ns.PinnedBuff() ~= nil or #ns.ClassBlessings() < 2\n",
       "\treturn #ns.ClassBlessings() < 2\n",
       "forclass: the choice shown while one blessing is pinned",
       expect="forclass: the page picks a class, gives it a blessing and clears them all", script=S)

mutate("Core.lua",
       "\tif not (ns.EXCLUSIVE_BUFFS and ns.EXCLUSIVE_BUFFS[playerClass]) then return out end\n",
       "",
       "forclass: a class whose buffs stack given the choice",
       expect="forclass: a class whose buffs stack has no such choice", script=S)

mutate("Options/Advanced.lua",
       "\"buff.keptBack\", \"buff.forClass\",\n",
       "\"buff.keptBack\",\n",
       "forclass: the page's reset leaves a class's blessing",
       expect=" reset: the list leaves out ", script=S)
