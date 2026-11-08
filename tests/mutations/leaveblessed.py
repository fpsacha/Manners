# Mutations for skipping players another paladin has blessed (Core.lua,
# PickBuffFor's exclusive branch and the default, Options/Who.lua, the layout
# slot and the page's reset). Each is caught by the scenario in
# tests/scenarios/leaveblessed.lua (or model-window.lua) that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tif db.buff.leaveBlessed == true and not opts.asked then\n",
       "\t\t\tif false then\n",
       "leaveblessed: the setting is never read",
       expect="leaveblessed: vanilla: another paladin's Might leaves them alone with the switch on", script=S)

mutate("Core.lua",
       "\t\t\tif db.buff.leaveBlessed == true and not opts.asked then\n",
       "\t\t\tif not opts.asked then\n",
       "leaveblessed: held back with the switch off",
       expect="leaveblessed: vanilla: another paladin's Might still gets Kings with the switch off", script=S)

mutate("Core.lua",
       "\t\t\tif db.buff.leaveBlessed == true and not opts.asked then\n",
       "\t\t\tif db.buff.leaveBlessed == true then\n",
       "leaveblessed: an ask by name held back too",
       expect="leaveblessed: somebody who asks for a blessing is still offered it", script=S)

mutate("Core.lua",
       "\t\t\t\tlocal all = ns.GetClassBuffs(playerClass) or candidates\n",
       "\t\t\t\tlocal all = candidates\n",
       "leaveblessed: a pin narrows what is read",
       expect="leaveblessed: vanilla: a pinned Kings is held back from another paladin's Wisdom", script=S)

mutate("Core.lua",
       "\t\t\tleaveBlessed = false,\n",
       "\t\t\tleaveBlessed = true,\n",
       "leaveblessed: on by default",
       expect="leaveblessed: Who to buff has the switch for a paladin, off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return not ns.EXCLUSIVE_BUFFS[ns.caps.class] end,\n\t\t\t\tget = function() return B().leaveBlessed == true end,\n",
       "\t\t\t\tget = function() return B().leaveBlessed == true end,\n",
       "leaveblessed: the switch shown to every class",
       expect="leaveblessed: a mage is not shown the switch", script=S)

mutate("Options/Window/Layout.lua",
       "\titems[#items + 1] = \"who.leaveBlessed\"\n",
       "",
       "leaveblessed: the switch is not placed on the page",
       expect="every control has one place in the options window", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.leaveBlessed\",\n",
       "",
       "leaveblessed: the page's reset leaves the switch",
       expect="model: the reset puts who back", script=S)
