# Manners: Combat loads as a separate default-on addon and plugs in through MannersAPI.

S = "runscenarios.py"
N = "combat-module: "

mutate("Modules/Combat/Manners_Combat.toc",
       "## DefaultState: enabled\n",
       "## DefaultState: disabled\n",
       "combat-module: the optional module ships disabled",
       expect=N + "the addon owns every fight button", script=S)

mutate("Modules/Combat/Layout.lua",
       "button:SetSize(size, size)\n",
       "button:SetSize(size)\n",
       "combat-module: shared button layout passes one SetSize coordinate",
       expect=N + "the addon owns every fight button", script=S)

mutate("Modules/Combat/Init.lua",
       "api:RegisterModule(\"combat\", \"Manners: Combat\")\n",
       "",
       "combat-module: the loaded module never announces itself",
       expect=N + "the addon owns every fight button", script=S)

mutate("Manners.toc",
       "Queue.lua\n",
       "Queue.lua\nModules/Combat/Cures.lua\n",
       "combat-module: the core loads out-of-combat cures",
       expect=N + "the addon owns every fight button", script=S)

mutate("Options/Who.lua",
       "\tPage.AddResControls(who.args)\n",
       "\tPage.AddResControls(who.args)\n"
       "\twho.args.cures = { type = \"toggle\", name = \"Cures\" }\n",
       "combat-module: core options build cure settings",
       expect=N + "the addon owns every fight button", script=S)

mutate("Manners.toc",
       "Modules.lua\n",
       "",
       "combat-module: modules lose the public API",
       expect=N + "the addon owns every fight button", script=S)

mutate("Modules/Combat/MendPet.lua",
       '\treturn class == "HUNTER"\n',
       '\treturn false\n',
       "combat-module: Mend Pet depends on the Pets module",
       expect=N + "Mend Pet works without Manners: Pets", script=S)

