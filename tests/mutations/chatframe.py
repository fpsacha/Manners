# Mutations for Send Manners messages to (1.12.1): the chat lines off by
# default (Core.lua defaults), the chosen tab handed to the print (Core.lua
# addon:Print, addon:Reply, ns.ChatFrame, ns.ChatWindows), its control on
# Start here, its place in the window and its repair. Each is caught by the
# scenario in tests/scenarios/chatframe.lua that names it.

S = "runscenarios.py"

DEFAULT = "chatframe: the chat lines are off by default, and the default window is the one"
TAB = "chatframe: lines go to the tab chosen, a reply too"
GONE = "chatframe: a tab gone falls back to the default window"
CHOICE = "chatframe: the choice lists the default window and the open tabs, not the combat log"

mutate("Core.lua",
       "\t\tverbose = false,\n",
       "\t\tverbose = true,\n",
       "chatframe: the chat lines on by default again",
       expect=DEFAULT, script=S)

mutate("Core.lua",
       "\t\tif frame then return acePrint(self, frame, ...) end\n\t\treturn acePrint(self, ...)\n\tend\n\tfunction addon:Reply",
       "\t\treturn acePrint(self, ...)\n\tend\n\tfunction addon:Reply",
       "chatframe: Print ignores the tab chosen",
       expect=TAB, script=S)

mutate("Core.lua",
       "\t\tlocal frame = ns.ChatFrame(self.db and self.db.profile)\n",
       "\t\tlocal frame = nil\n",
       "chatframe: Reply ignores the tab chosen",
       expect=TAB, script=S)

mutate("Core.lua",
       "\t\tif tab.name == want then return tab.frame end\n",
       "\t\tif tab.name == want then return tab.frame end\n\t\tif tab.name ~= want then return tab.frame end\n",
       "chatframe: a tab not found goes to some other tab",
       expect=GONE, script=S)

mutate("Core.lua",
       "\t\tif type(name) == \"string\" and name ~= \"\" and (shown or docked)\n",
       "\t\tif type(name) == \"string\" and name ~= \"\"\n",
       "chatframe: a closed tab still counts",
       expect=GONE, script=S)

mutate("Core.lua",
       "\t\t\tand name ~= _G.COMBAT_LOG then\n",
       "\t\t\tthen\n",
       "chatframe: the combat log is offered",
       expect=CHOICE, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"general.chatFrame\",\n",
       "",
       "chatframe: the window never places the choice",
       expect=CHOICE, script=S)

mutate("Core.lua",
       "\t\tchat = { frame = \"\" },\n",
       "\t\tchat = { frame = \"General\" },\n",
       "chatframe: a tab chosen by default",
       expect=DEFAULT, script=S)
