# Mutations for the exact, opt-in Services casts and their zero-work gates.

S = "runscenarios.py"

mutate("Modules/Services/Courtesy.lua",
       "\t\tif kind.targeted then\n\t\t\tlocal up = AuraUp(unit, kind.aura or spell)\n\t\t\tif up == nil then return nil, \"read\" end\n\t\t\tif up then return nil, \"up\" end\n",
       "\t\tif kind.targeted then\n\t\t\tlocal up = AuraUp(unit, kind.aura or spell)\n\t\t\tif up == nil then return nil, \"read\" end\n\t\t\tif false then return nil, \"up\" end\n",
       "services-utilities: a service is offered over its aura",
       expect="services-utilities: explicit utility requests prove target, aura, range, reagent and cooldown",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\tif kind.targeted and InRange(spell, unit) ~= true then return nil, \"range\" end\n",
       "\t\tif false and kind.targeted and InRange(spell, unit) ~= true then return nil, \"range\" end\n",
       "services-utilities: a service is offered out of range",
       expect="services-utilities: explicit utility requests prove target, aura, range, reagent and cooldown",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\tif type(secret) == \"function\" and secret(answer) == true then return false end\n",
       "",
       "services-utilities: a secret spell-usability answer is trusted",
       expect="services-utilities: explicit utility requests prove target, aura, range, reagent and cooldown",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\tif Cooling(spell) then return nil, \"cooldown\" end\n\t\tif not Usable(spell) then return nil, \"unusable\" end\n\t\tif kind.targeted and InRange",
       "\t\tif false and Cooling(spell) then return nil, \"cooldown\" end\n\t\tif not Usable(spell) then return nil, \"unusable\" end\n\t\tif kind.targeted and InRange",
       "services-utilities: a service is offered on cooldown",
       expect="services-utilities: explicit utility requests prove target, aura, range, reagent and cooldown",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\tif not targetRefresh and not ChatAllowed(name, st) then return nil, \"scope\" end\n",
       "\tif false and not targetRefresh and not ChatAllowed(name, st) then return nil, \"scope\" end\n",
       "services-utilities: a request source switched off is accepted",
       expect="services-utilities: request scope, combat, instance and matching are independent per service",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\t\t\t\tif Known(spell) and Courtesy.Destination(spell) then\n",
       "\t\t\t\t\tif Known(spell) then\n",
       "services-utilities: a portal destination switched off is accepted",
       expect="services-utilities: portal destinations are explicit and TBC uses its learned Soulwell",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\tif not Courtesy.Destination(spell) then return nil, \"destination\" end\n",
       "\t\tif false and not Courtesy.Destination(spell) then return nil, \"destination\" end\n",
       "services-utilities: a standing portal ignores its destination switch",
       expect="services-utilities: portal destinations are explicit and TBC uses its learned Soulwell",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\tif not ModuleOn() then return Listen(false) end\n",
       "\tif not ModuleOn() then return Listen(true) end\n",
       "services-utilities: disabled Services creates its request frame",
       expect="services-module: target refreshments and Fire Shield attach",
       script=S)

mutate("Modules/Services/FireShield.lua",
       "\tlocal on = On() == true\n",
       "\tlocal on = true\n",
       "services-utilities: Fire Shield registers while its switch is off",
       expect="services-module: target refreshments and Fire Shield attach",
       script=S)

mutate("Modules/Services/Options.lua",
       "end, layout, \"modules\")",
       "end, layout, \"support\")",
       "services-utilities: the Services options page leaves its module group",
       expect="services-module: target refreshments and Fire Shield attach",
       script=S)

mutate("Modules.lua",
       "\telse\n\t\tpendingReload[id] = enabled\n\tend\n\tlocal active = api:ModuleActive(id)\n",
       "\telse\n\t\tpendingReload[id] = nil\n\tend\n\tlocal active = api:ModuleActive(id)\n",
       "services-utilities: disabling loaded Services loses pending reload state",
       expect="modules: disabling loaded Services stops its runtime immediately and still asks for Reload UI",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\twipe(waiting)\n",
       "",
       "services-utilities: suspended Services keeps an in-flight cast",
       expect="modules: disabling loaded Services stops its runtime immediately and still asks for Reload UI",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\t\t\tif type(key) == \"string\" and key:sub(1, 9) == \"courtesy:\" then keys[key] = nil end\n",
       "\t\t\t\tif false then keys[key] = nil end\n",
       "services-utilities: suspended Services keeps its standing request alive",
       expect="modules: disabling loaded Services stops its runtime immediately and still asks for Reload UI",
       script=S)

mutate("Core.lua",
       "\tif ns.Courtesy and ns.Courtesy.Active and ns.Courtesy.Active() then return true end\n",
       "",
       "services-utilities: a Services-only class has no castable prompt",
       expect="services-utilities: a learned service alone gives a class a castable prompt",
       script=S)

mutate("Options/Shared.lua",
       "\tif ns.Courtesy and ns.Courtesy.Active and ns.Courtesy.Active() then return true end\n",
       "",
       "services-utilities: Start here hides a Services-only class's prompt",
       expect="services-utilities: a learned service alone gives a class a castable prompt",
       script=S)

mutate("Requests.lua",
       "\t\t\t\tfiltered = filter(keys, channel)\n",
       "\t\t\t\tfiltered = filter(keys, channel) or (channel == \"WHISPER\" and keys or nil)\n",
       "services-utilities: an ignored combat whisper falls through to the core hold",
       expect="services-utilities: request scope, combat, instance and matching are independent per service",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\treturn st.onTarget == true and Scope(name, \"target\")\n",
       "\treturn st.pointed == true and Scope(name, \"target\")\n",
       "services-utilities: focus is accepted as the current target",
       expect="services-utilities: request scope, combat, instance and matching are independent per service",
       script=S)
