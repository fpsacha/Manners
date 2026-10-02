# Where the options window (Options/Window/Window*.lua, Bind.lua) and its rows
# (Options/Window/Widgets*.lua) meet: the context the window hands every row,
# and the confirm box. Each fault is caught by the scenario in
# tests/scenarios/window.lua or window-widgets.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# A row that grows by itself (a refusal under its box) left in a slot laid
# out for its old height.
mutate("Options/Window/Window.lua",
       "\tRelayout = function() ns.Guard(\"options relayout\", UI.Relayout) end,\n",
       "",
       "window: no relayout for a row that grew",
       expect="the red sentence made the New box's row", script=S)

# A slider held on Look no longer reaching the window's fade.
mutate("Options/Window/Window.lua",
       "\tOnHold = function(on) ns.Guard(\"options window\", UI.Held, on) end,\n",
       "\tOnHold = function() end,\n",
       "window: a held slider does not fade the window",
       expect="holding the Scale slider left the window at", script=S)

# The colour picker opened without telling the window it is held open...
mutate("Options/Window/WidgetsChoice.lua",
       "\tpicking = row\n\tW.Hold(row, true)\n",
       "\tpicking = row\n",
       "window: the colour picker does not fade the window",
       expect="with the colour picker open for Panel colour the window is at", script=S)

# ...and shut without letting go.
mutate("Options/Window/WidgetsChoice.lua",
       "\tif row then W.Hold(row, false) end\n",
       "",
       "window: the colour picker shut leaves the window faded",
       expect="the colour picker shut and the window stayed at", script=S)

# A confirm skipped: the footer's reset went straight through.
mutate("Options/Window/Bind.lua",
       "\tlocal text = ConfirmText(item, ...)\n",
       "\tlocal text = nil\n",
       "window: the reset does not ask first",
       expect="the reset did not ask first", script=S)
