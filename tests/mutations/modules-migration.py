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
       "\tif profile.optionalModulesMigrated ~= true then profile.optionalModulesMigrated = true end\n",
       "",
       "modules-migration: a completed migration is not marked",
       expect="modules migration #64: old active own buffs load My Buffs and restore self learning",
       script=S)

mutate("Modules.lua",
       "\tif legacyProfile == true and profile.optionalCombatMigrated ~= true then\n",
       "\tif false and profile.optionalCombatMigrated ~= true then\n",
       "modules-migration: legacy Combat switches are ignored",
       expect="modules migration: old active Combat switches load Combat",
       script=S)

mutate("Modules.lua",
       "or prompt.reactiveWards == true)",
       "or false)",
       "modules-migration: reactive wards do not enable Combat",
       expect="modules migration: any active legacy Combat-only switch loads Combat",
       script=S)
