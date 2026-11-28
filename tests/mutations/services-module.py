mutate(
    "Core.lua",
    "courtesyTarget = false,",
    "courtesyTarget = true,",
    "services-module: target refreshments are off by default",
    expect="services-module: target refreshments and Fire Shield attach",
    script="runscenarios.py",
)

mutate(
    "Modules/Services/Init.lua",
    'api:RegisterCallback("CoreReady", Sync)\n',
    "",
    "services-module: Fire Shield saved in the profile never attaches",
    expect="services-module: saved Fire Shield attaches after the profile is ready",
    script="runscenarios.py",
)

mutate(
    "Prompt/Fight.lua",
    "\t\tif outOnly or (entry.remembered and entry.reason == \"nearby\") then\n",
    "\t\tif entry.remembered and entry.reason == \"nearby\" then\n",
    "services-module: Fire Shield is frozen onto the fight rota",
    expect="fireshield: the pull never freezes this out-of-combat service onto the fight rota",
    script="runscenarios.py",
)

mutate(
    "Modules/Services/FireShield.lua",
    "\t\tneverInCombat = true,\n",
    "",
    "services-module: Fire Shield is not marked out of combat",
    expect="fireshield: the pull never freezes this out-of-combat service onto the fight rota",
    script="runscenarios.py",
)

mutate(
    "Modules/Services/Options.lua",
    'L["A person allowed below who asks for water is offered the best conjured rank that suits their level. With none in your bags, the first press conjures it and the next opens a trade."], 70.10)\n',
    'L["A person allowed below who asks for water is offered the best conjured rank that suits their level. With none in your bags, the first press conjures it and the next opens a trade."], 70.00)\n',
    "services-module: a service control collides with another in stripped options",
    expect="services-module: its page owns independent service and policy switches: separate service controls share a sort order",
    script="runscenarios.py",
)
