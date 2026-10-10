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

# The colour picker fading the window: the hold it tells the window about
# and, since 1.7.4, the picker itself being up (W.PickerUp) both do it, so the
# fault is the window ignoring a hold altogether...
mutate("Options/Window/Window.lua",
       "\tlocal held = (peek.held or ns.WindowWidgets.PickerUp()) and onLook\n",
       "\tlocal held = false\n",
       "window: the colour picker does not fade the window",
       expect="with the colour picker open for Panel colour the window is at", script=S)

# ...and the picker's own state not being read, so a slider let go of while
# the picker is still up ends the fade.
mutate("Options/Window/WidgetsChoice.lua",
       "\treturn picking ~= nil and type(picker) == \"table\" and picker.IsShown and picker:IsShown() and true or false\n",
       "\treturn false\n",
       "window: the picker's own state not read",
       expect="Scale let go with the colour picker up left the window at", script=S)

# ...and shut without letting go. Since 1.6.1 the window lets go by itself
# once the picker is down, so it is the widget's own check that sees it.
mutate("Options/Window/WidgetsChoice.lua",
       "\tif row then W.Hold(row, false) end\n",
       "",
       "window: the colour picker shut leaves the window faded",
       expect="the window was not told the picker shut", script=S)

# A confirm skipped: the footer's reset went straight through.
mutate("Options/Window/Bind.lua",
       "\tlocal text = ConfirmText(item, ...)\n",
       "\tlocal text = nil\n",
       "window: the reset does not ask first",
       expect="the reset did not ask first", script=S)
