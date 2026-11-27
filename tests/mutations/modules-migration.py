# One-time migrations for feature state moved behind optional addon folders.

S = "runscenarios.py"

mutate("Core.lua",
       '\tif modules and type(modules.MigrateOptionalModules) == "function" then\n'
       '\t\tmodules:MigrateOptionalModules(self.legacyModuleDatabase)\n'
       '\tend\n',
       "",
       "modules-migration: old profiles skip optional-module migration",
       expect="modules migration #64: old active own buffs load My Buffs and restore self learning",
       script=S)

mutate("Modules.lua",
       '\treturn type(sources) == "table" and sources.self == true\n',
       '\treturn false\n',
       "modules-migration: active legacy own buffs are ignored",
       expect="modules migration #64: old active own buffs load My Buffs and restore self learning",
       script=S)

mutate("Modules.lua",
       "\tprofile.optionalModulesMigrated = true\n",
       "",
       "modules-migration: a completed migration is not marked",
       expect="modules migration #64: old active own buffs load My Buffs and restore self learning",
       script=S)
