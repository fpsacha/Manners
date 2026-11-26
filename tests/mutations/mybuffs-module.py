mutate(
    "Core.lua",
    "function ns.OffersSelf()\n\tif not (ns.ModuleActive and ns.ModuleActive(\"mybuffs\")) then return false end\n",
    "function ns.OffersSelf()\n",
    "mybuffs-module: the core cannot offer own buffs without its module",
    expect="mybuffs-module: core owns no self extras without the module",
    script="runscenarios.py",
)

mutate(
    "Modules/MyBuffs/Options.lua",
    "ns.FindOwnFamily(family.splitTo)",
    "ns.OWN_FAMILY_BY_KEY[family.splitTo]",
    "mybuffs-module: options read a private family map",
    expect="mybuffs-module: split own families use a scoped accessor",
    script="runscenarios.py",
)
