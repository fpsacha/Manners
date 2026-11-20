# The options window's scroll bars, the page's and a box's, dragged by the
# cursor in Lua (Options/Window/Widgets.lua, W.DragBar and W.PlaceThumb;
# Window.lua, UI.ScrollTo; WidgetsEntry.lua, ScrollBar). Each fault is caught
# by the scenario in tests/scenarios/scrollbar.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "scrollbar: "
WIDGETS = "Options/Window/Widgets.lua"
WINDOW = "Options/Window/Window.lua"
ENTRY = "Options/Window/WidgetsEntry.lua"

# The drag turned over: the mouse moving down scrolls the page up.
mutate(WIDGETS,
       "bar._write(grab.from + (grab.cy - cy) * (tonumber(range) or 0) / grab.travel)",
       "bar._write(grab.from + (cy - grab.cy) * (tonumber(range) or 0) / grab.travel)",
       "scrollbar: the drag runs backwards",
       expect=P + "dragging the page bar down scrolls the page down", script=S)

# The page scrolls and the thumb stays where it was.
mutate(WINDOW,
       "\tview.scroll:SetVerticalScroll(y)\n\tns.WindowWidgets.PlaceThumb(view.bar)\nend",
       "\tview.scroll:SetVerticalScroll(y)\nend",
       "scrollbar: the thumb stays put",
       expect=P + "the thumb follows the page", script=S)

# The client's word that the button is up is not asked: the drag runs on.
mutate(WIDGETS,
       "\tif type(IsMouseButtonDown) == \"function\" and not IsMouseButtonDown(\"LeftButton\") then return LetGo(bar) end\n",
       "",
       "scrollbar: the drag never lets go",
       expect=P + "letting go ends the drag", script=S)

# A click on the track does nothing but grab where the thumb already is.
mutate(WIDGETS,
       "\tif cy > top or cy < top - thumb:GetHeight() then\n",
       "\tif false then\n",
       "scrollbar: a click on the track does nothing",
       expect=P + "a click on the track below the thumb scrolls down", script=S)

# A box's bar writes the box's scroll from the wrong end.
mutate(ENTRY,
       "row.scroll:SetVerticalScroll(math.max(0, math.min(BarRange(row), tonumber(y) or 0)))",
       "row.scroll:SetVerticalScroll(math.max(0, math.min(BarRange(row), BarRange(row) - (tonumber(y) or 0))))",
       "scrollbar: a box's bar scrolls the wrong way",
       expect=P + "a box's bar drags its text the same way", script=S)
