# The optional-folder public API and dynamic options bridge.

S = "runscenarios.py"
N = "modules-plumbing: "

mutate("Modules.lua",
       "_G.MannersAPI = api\n",
       "",
       "modules-plumbing: the module API is kept private",
       expect=N + "the core publishes a small independent module API", script=S)

mutate("Modules.lua",
       "\tif ns.RefreshModuleOptions then ns.RefreshModuleOptions() end\n",
       "",
       "modules-plumbing: a page registered after options load is never installed",
       expect=N + "the core publishes a small independent module API", script=S)

mutate("Options/Register.lua",
       "\t\t\tif type(built) == \"table\" then options.args[id] = built end\n",
       "",
       "modules-plumbing: module pages never enter the options model",
       expect=N + "the core publishes a small independent module API", script=S)

mutate("Modules.lua",
       '\t\t\tns.Guard("module attach " .. id, ns.ProbeCapabilities)\n',
       "",
       "modules-plumbing: late modules never re-probe capabilities",
       expect="modules-plumbing: late module attach reprobes once", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tget = function()\n\t\t\t\t\tif not ns.BreakFree or type(ns.BreakFree.COMMAND) ~= \"string\" then return \"\" end\n",
       "\t\t\t\tget = function()\n",
       "modules-plumbing: the BreakFree key row dereferences an absent module",
       expect="modules: core options never call a disabled Combat cure chooser", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tget = function()\n\t\t\t\t\tif not ns.MendPet or type(ns.MendPet.COMMAND) ~= \"string\" then return \"\" end\n",
       "\t\t\t\tget = function()\n",
       "modules-plumbing: the Mend Pet key row dereferences an absent module",
       expect="modules: core options never call a disabled Combat cure chooser", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tget = function()\n\t\t\t\t\tif not ns.CureFight or type(ns.CureFight.COMMAND) ~= \"string\" then return \"\" end\n",
       "\t\t\t\tget = function()\n",
       "modules-plumbing: the cure key row dereferences an absent module",
       expect="modules: core options never call a disabled Combat cure chooser", script=S)

mutate("Options/Look.lua",
       "\t\tif not ns.CureFight or type(ns.CureFight.Chosen) ~= \"function\" then return \"none\" end\n",
       "\t\tlocal plain, shift, ctrl = ns.CureFight.Chosen()\n",
       "modules-plumbing: the cure dropdown dereferences an absent module",
       expect="modules: core options never call a disabled Combat cure chooser", script=S)

mutate("Modules.lua",
       "\t\tstate = ns.plain(state)\n\t\tif type(state) == \"number\" then return state ~= 0 end\n\t\treturn loaded[id] ~= nil\n",
       "\t\treturn ns.plain(state) ~= 0\n",
       "modules-plumbing: an unknown addon state reads as enabled",
       expect="modules: unknown addon enable states do not read as enabled", script=S)

mutate("Modules.lua",
       "\tif not changed then return false end\n",
       "",
       "modules-plumbing: a missing enable API reports a successful change",
       expect="modules: unknown addon enable states do not read as enabled", script=S)

mutate("Modules.lua",
       "function ns.ModuleActive(id)\n"
       "\tlocal runtime = loaded[id] ~= nil\n"
       "\tif not runtime then return false end\n",
       "function ns.ModuleActive(id)\n"
       "\tlocal runtime = loaded[id] ~= nil\n",
       "modules-plumbing: an unloaded pending module is active before reload",
       expect="modules-plumbing: enabling an unloaded module waits for Reload UI",
       script=S)

mutate("Prompt/Hold.lua",
       "\tif ModuleRetired(entry) then return true end\n",
       "",
       "modules-plumbing: suspended module entry survives the prompt retire",
       expect="modules: disabling loaded Combat stops cures and combat events before Reload UI",
       script=S)

mutate("Prompt/Hold.lua",
       "\tif ModuleRetired(S.heldEntry) then return false end\n",
       "",
       "modules-plumbing: suspended module entry remains preferred by the prompt hold",
       expect="modules: disabling loaded Services stops its runtime immediately and still asks for Reload UI",
       script=S)

mutate("Options/Start.lua",
       "\t\t\t\thidden = function() local api = _G.MannersAPI return not (api and api:ModuleReloadPending()) end,\n"
       "\t\t\t\tdisabled = function() return InCombatLockdown() end,\n",
       "\t\t\t\thidden = function() local api = _G.MannersAPI return not (api and api:ModuleReloadPending()) end,\n",
       "modules-plumbing: Reload UI stays live in combat",
       expect="modules: the Reload UI button is disabled in combat", script=S)

mutate("Modules.lua",
       "\tif enabled == (loaded[id] ~= nil) then\n"
       "\t\tpendingReload[id] = nil\n"
       "\telse\n"
       "\t\tpendingReload[id] = enabled\n"
       "\tend\n",
       "\tif enabled == (loaded[id] ~= nil) then\n"
       "\t\tpendingReload[id] = enabled\n"
       "\telse\n"
       "\t\tpendingReload[id] = enabled\n"
       "\tend\n",
       "modules-plumbing: reverting a module still asks for Reload UI",
       expect="modules: the Manners menu enables and disables addon folders", script=S)

mutate("Modules.lua",
       "\tif not api:CanToggleModule(id) then return false end\n",
       "",
       "modules-plumbing: module addon state changes for loaded modules in combat",
       expect="modules: combat locks every loaded module switch and the API", script=S)

mutate("Modules.lua",
       "return not InCombatLockdown() or loaded[id] == nil\n",
       "return not InCombatLockdown()\n",
       "modules-plumbing: an unloaded module cannot be enabled in combat",
       expect="modules: an unloaded module can be enabled in combat and repaints",
       script=S)

mutate("Modules.lua",
       "chat.EnableAddOn(folder, AddOnCharacter())\n",
       "chat.EnableAddOn(folder)\n",
       "modules-plumbing: C_AddOns enable ignores the current character",
       expect="modules: an unloaded module can be enabled in combat and repaints",
       script=S)

mutate("Modules/Combat/Cures.lua",
       "function ns.CuresWanted(db)\n"
       "\tif not CombatActive() then return false end\n",
       "function ns.CuresWanted(db)\n",
       "modules-plumbing: disabled Combat still owns out-of-fight cures",
       expect="modules: disabling loaded Combat stops cures and combat events before Reload UI",
       script=S)

mutate("Modules.lua",
       "\tif enabled == (loaded[id] ~= nil) then\n"
       "\t\tpendingReload[id] = nil\n"
       "\telse\n"
       "\t\tpendingReload[id] = enabled\n"
       "\tend\n"
       "\tlocal active = api:ModuleActive(id)\n"
       "\tif active ~= wasActive then\n"
       "\t\tSetModuleActive(id, active)\n"
       "\tend\n",
       "\tif enabled == (loaded[id] ~= nil) then\n"
       "\t\tpendingReload[id] = nil\n"
       "\telse\n"
       "\t\tpendingReload[id] = enabled\n"
       "\tend\n"
       "\tlocal active = api:ModuleActive(id)\n"
       "\tif active ~= wasActive then\n"
       "\t\t-- no lifecycle\n"
       "\tend\n",
       "modules-plumbing: a loaded module is not suspended immediately",
       expect="modules: disabling loaded Combat stops cures and combat events before Reload UI",
       script=S)

mutate("Modules.lua",
       "\tlocal lifecycle = lifecycles[id]\n"
       "\tif lifecycle then\n"
       "\t\tlocal where = active and \"resume \" or \"suspend \"\n"
       "\t\tns.Guard(where .. id, active and lifecycle.resume or lifecycle.suspend)\n"
       "\tend\n",
       "\tlocal lifecycle = nil\n"
       "\tif lifecycle then\n\tend\n",
       "modules-plumbing: registered module lifecycle does not run",
       expect="modules-plumbing: one lifecycle runs suspend and resume for a loaded module",
       script=S)

mutate("Modules/Pets/HunterPet.lua",
       "function Beast.Suspend()\n"
       "\tListenEvents(false)\n"
       "end\n",
       "function Beast.Suspend()\n"
       "end\n",
       "modules-plumbing: disabling Pets leaves its event frame live",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Modules/Pets/HunterPet.lua",
       "function Beast.Resume()\n"
       "\tListen()\n"
       "\tst.dirty, st.auraDirty = true, true\n"
       "end\n",
       "function Beast.Resume()\n"
       "end\n",
       "modules-plumbing: re-enabling Pets does not resume its frame",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Modules/Pets/HunterPet.lua",
       "function Beast.Resume()\n"
       "\tListen()\n"
       "\tst.dirty, st.auraDirty = true, true\n"
       "end\n",
       "function Beast.Resume()\n"
       "\tListen()\n"
       "end\n",
       "modules-plumbing: re-enabling Pets keeps stale pet cache",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Modules/Pets/HunterPetHints.lua",
       "function Beast.SuspendHints()\n"
       "\tif frame then frame:UnregisterAllEvents() end\n"
       "\tstarted = false\n"
       "end\n",
       "function Beast.SuspendHints()\n"
       "end\n",
       "modules-plumbing: disabling Pets leaves its hint frame live",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Modules/MyBuffs/Init.lua",
       "\tif ns.Pet and ns.Pet.SetListening then ns.Pet:SetListening(false) end\n",
       "\tif ns.Pet and ns.Pet.SetListening then ns.Pet:SetListening(true) end\n",
       "modules-plumbing: disabling My Buffs leaves companion events live",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "function Pet:SetListening(on)\n"
       "\tlocal frame = Pet.frame\n",
       "function Pet:SetListening(on)\n"
       "\tif on then return end\n"
       "\tlocal frame = Pet.frame\n",
       "modules-plumbing: re-enabling My Buffs does not resume companion events",
       expect="modules: loaded Pets and My Buffs stop runtime work before Reload UI",
       script=S)

mutate("Options/Advanced.lua",
       "\t[\"beast.fightMend\"] = \"combat\",\n",
       "",
       "modules-plumbing: a core reset owns Combat's Mend Pet switch",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)

mutate("Options/Advanced.lua",
       "\t[\"supplies.size\"] = \"mybuffs\",\n",
       "",
       "modules-plumbing: Look's reset owns the My Buffs supplies button",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)

mutate("Options/Advanced.lua",
       "\t[\"prompt.cureFight\"] = \"combat\",\n",
       "",
       "modules-plumbing: Who to buff resets a disabled Combat cure",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)

mutate("Options/Advanced.lua",
       "\t[\"sources.cures\"] = \"combat\",\n",
       "",
       "modules-plumbing: a core reset owns Combat's out-of-fight cure switch",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)

mutate("Options/Advanced.lua",
       "\t[\"filters.cureSeconds\"] = \"combat\",\n",
       "",
       "modules-plumbing: a core reset owns Combat's cure duration",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)

mutate("Options/Advanced.lua",
       "\tlocal serviceFireShield = path == \"buff.optIn\" and type(current) == \"table\"\n"
       "\t\tand current.fireshield == true or nil\n",
       "\tlocal serviceFireShield\n",
       "modules-plumbing: the core buff reset erases Services' Fire Shield",
       expect="modules: core page resets keep settings owned by disabled modules",
       script=S)
