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
       "\tif modulesDone then profile.optionalModulesMigrated = true end\n",
       "\tif false then profile.optionalModulesMigrated = true end\n",
       "modules-migration: a completed migration is not marked",
       expect="modules migration #64: old active own buffs load My Buffs and restore self learning",
       script=S)

mutate("Modules.lua",
       "\tif legacyProfile == true and not combatDone then\n",
       "\tif legacyProfile == false and not combatDone then\n",
       "modules-migration: legacy Combat switches are ignored",
       expect="modules migration: old active Combat switches load Combat",
       script=S)

mutate("Modules.lua",
       "or prompt.reactiveWards == true)",
       "or false)",
       "modules-migration: reactive wards do not enable Combat",
       expect="modules migration: any active legacy Combat-only switch loads Combat",
       script=S)

mutate("Modules.lua",
       "\t\tif type(later) == \"function\" then later(1, function() Attempt(token) end)\n",
       "\t\tif type(later) == \"function\" then later(1, function() token.profile.moduleWelcome1125 = true end)\n",
       "modules-migration: the chooser is consumed before presentation",
       expect="modules: chooser is marked only when actually presented",
       script=S)

mutate("Modules.lua",
       "\t\tif InCombatLockdown() then return false end\n",
       "\t\tif InCombatLockdown() then token.profile.moduleWelcome1125 = true return false end\n",
       "modules-migration: combat consumes the outstanding chooser",
       expect="modules: chooser is marked only when actually presented",
       script=S)

mutate("Modules.lua",
       "\t\telseif moduleWelcomeToken then Attempt(moduleWelcomeToken)\n",
       "",
       "modules-migration: a blocked chooser is not retried",
       expect="modules: chooser retries when the delayed window cannot present",
       script=S)

mutate("Modules.lua",
       "\t\tif not CurrentToken(token) or token.profile.moduleWelcome1125 == true then\n",
       "\t\tif token.profile.moduleWelcome1125 == true then\n",
       "modules-migration: stale chooser callback replaces the current profile",
       expect="modules: chooser callback stays bound to its profile",
       script=S)

mutate("Modules.lua",
       "\tlocal character = MigrationCharacter()\n",
       "\tlocal character = \"shared\"\n",
       "modules-migration: shared profiles migrate folders only for the first character",
       expect="modules migration: a shared profile migrates each character once",
       script=S)

mutate("Modules.lua",
       "\tif not modulesDone and modulesReady then\n",
       "\tif not modulesDone and false then\n",
       "modules-migration: migration never remembers an intentional disable",
       expect="modules migration: a shared profile migrates each character once",
       script=S)

mutate("Options/Start.lua",
       "\t\t\tor key == \"optionalCombatMigrated\" and value == true\n",
       "",
       "modules-migration: Combat migration stamps make a visited profile real",
       expect="modules migration: marker-only profile state still counts as unvisited",
       script=S)
