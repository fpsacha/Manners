# The key box takes keys through a focused hidden text field
# (Options/Window/WidgetsChoice.lua, Grabber), as WoW Forever needs.

mutate("Options/Window/WidgetsChoice.lua",
       "\tGrabber(row):SetFocus()\n",
       "\tGrabber(row)\n",
       "widgets-keyfocus: the capture never takes the keyboard focus",
       expect="widgets: a key reaches the box through the focus", script="runscenarios.py")

mutate("Options/Window/WidgetsChoice.lua",
       "\t\tif capturing == self.row then StopCapture(self.row) end\n",
       "",
       "widgets-keyfocus: losing the focus leaves the box waiting",
       expect="widgets: a key reaches the box through the focus", script="runscenarios.py")
