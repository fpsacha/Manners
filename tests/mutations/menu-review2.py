# Mutations for the second review of the menu: the reminder to set a key
# (Options/Start.lua, Commands.lua) and the simple view (Options/Window/
# Layout.lua, WindowSearch.lua, WindowChrome.lua). Each undoes one fix and is
# caught by the scenario in tests/scenarios/menu-review2.lua that names it.

S = "runscenarios.py"

START = "the reminder says /manners opens Start here, and it opened"
ONCE = "a later /manners opened"
SILENT = "nothing was said and"
VIA = "and its result left the view"
STRIP = "the strip speaks of targeting in the simple view"
SCROLLS = "the simple view does not draw the switch that turns it back on"

# /manners opens the page last open, whatever the reminder just said.
mutate("Commands.lua",
       "\t\tns.OpenOptions(ns.Setup and ns.Setup.ReminderPage and ns.Setup.ReminderPage() or nil)\n",
       "\t\tns.OpenOptions()\n",
       "menu-review2: /manners after the reminder opens the page last open",
       expect=START, script=S)

# Start here at every /manners of the session, not the one the reminder sent.
mutate("Options/Start.lua",
       "\tif not reminder.lead then return nil end\n\treminder.lead = false\n",
       "\tif not reminder.lead then return nil end\n",
       "menu-review2: every /manners after the reminder opens Start here",
       expect=ONCE, script=S)

# A reminder is counted as said while the chat switch drops its line.
mutate("Options/Start.lua",
       "\tif profile.silentChat == true then return \"chat messages are hidden\" end\n",
       "",
       "menu-review2: the reminder is used up unseen with chat hidden",
       expect=SILENT, script=S)

# A result behind a switch shows the switch and leaves the short list on.
mutate("Options/Window/WindowSearch.lua",
       "\tif ref.via and UI.OffShortList(ref.via) then ns.SetMenuView(\"full\") end\n",
       "",
       "menu-review2: a result behind a switch keeps the simple view",
       expect=VIA, script=S)

# The combat line goes by the model's rule and the fold alone.
mutate("Options/Window/WindowChrome.lua",
       "\tif UI.HiddenBySimple(path) then return false end\n",
       "",
       "menu-review2: the combat line speaks of a control the simple view leaves out",
       expect=STRIP, script=S)

# The short list without the Scrolls switch.
mutate("Options/Window/Layout.lua",
       "\t\t\t[\"who.ownScrolls\"] = true,\n",
       "",
       "menu-review2: the short list has no Scrolls switch",
       expect=SCROLLS, script=S)
