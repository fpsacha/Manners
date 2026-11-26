# The task-based options hierarchy and the dedicated Modules page.

S = "runscenarios.py"
N = "menu-overhaul: "

mutate("Options/Window/Layout.lua",
       '\t\t[2] = L["Buffing"],\n',
       "",
       "menu-overhaul: the sidebar has no Buffing category",
       expect=N + "sidebar categories group pages by task", script=S)

mutate("Options/Window/Layout.lua",
       "\t\tpages = { modules = true },\n",
       "\t\tpages = {},\n",
       "menu-overhaul: Modules disappears from Simple view",
       expect=N + "the Modules page stays available in Simple view", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t{ \"modules\" },\n",
       "",
       "menu-overhaul: Modules has no sidebar group",
       expect=N + "sidebar categories group pages by task", script=S)

mutate("Modules.lua",
       '\t\t\t\t\t\tif page == "modules" then moduleGroup = group break end\n',
       '\t\t\t\t\t\tif page == "profiles" then moduleGroup = group break end\n',
       "menu-overhaul: loaded module pages join Support",
       expect=N + "sidebar categories group pages by task", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\t\tif label then\n\t\t\t\tlabel:SetText((layout.groupLabels or {})[gi] or \"\")\n",
       "\t\t\tif label then\n\t\t\t\tlabel:SetText(\"\")\n",
       "menu-overhaul: category labels are built but never named",
       expect=N + "sidebar category labels paint above their groups", script=S)

mutate("Options/Window/Layout.lua",
       '\t\t\t\t\t"general.howItWorks",\n',
       '\t\t\t\t\t"general.howItWorks",\n\t\t\t\t\t"general.modulesCombat",\n',
       "menu-overhaul: module switches move back to Start here",
       expect=N + "module switches live on their own page", script=S)

mutate("Options/Window/Layout.lua",
       '\t\t\t\t\t"general.modulesCombatHelp",\n',
       '\t\t\t\t\t{ "general.modulesCombatHelp", indent = true },\n',
       "menu-overhaul: a disabled module loses its description",
       expect=N + "disabled modules keep their descriptions visible", script=S)
