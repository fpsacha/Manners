# Mutations for what the options window wears (Options/Window/WindowDress.lua)
# and the places the window calls it from. Caught by
# tests/scenarios/window-dress.lua.

S = "runscenarios.py"
DRESS = "Options/Window/WindowDress.lua"

mutate("Options/Window/Window.lua",
       "\t-- What the window wears over all of it (WindowDress.lua).\n\tUI.Dress.Window(f)\n",
       "",
       "window-dress: the window wears no moulding",
       expect="the window wears no moulding", script=S)

mutate(DRESS,
       "\t\t{ \"TOPRIGHT\", \"TOPRIGHT\", o, o, c, c, 1 - k, 1, 0, k },\n",
       "\t\t{ \"TOPRIGHT\", \"TOPRIGHT\", o, o, c, c, 0, k, 0, k },\n",
       "window-dress: the top right corner drawn as the top left",
       expect="corner 2 of the moulding shows the wrong piece", script=S)

mutate(DRESS,
       "\t\t{ tl, \"TOPRIGHT\", tr, \"BOTTOMLEFT\", k, 1 - k, 0, k },\n",
       "\t\t{ tl, \"TOPRIGHT\", tr, \"BOTTOMLEFT\", 0, 1, 0, k },\n",
       "window-dress: the top side drawn with the corners in it",
       expect="the moulding's top side is not the strip between its corners", script=S)

mutate(DRESS,
       "\tframe:SetFrameLevel(f:GetFrameLevel() + 30)\n",
       "\tframe:SetFrameLevel(f:GetFrameLevel())\n",
       "window-dress: the moulding under the window's own panes",
       expect="the moulding is under the window", script=S)

mutate(DRESS,
       "\tt:SetTexCoord(0, width / RAIL_TILE, 0, 1)\n",
       "\tt:SetTexCoord(0, 1, 0, 1)\n",
       "window-dress: one tile of rail stretched across the window",
       expect="rail is not tiled along the window", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tUI.Dress.Footer(foot)\n",
       "",
       "window-dress: the footer without its rail",
       expect="the footer's rail is not tiled", script=S)

mutate("Options/Window/Widgets.lua",
       "\tif dress then dress.Button(b) end\n",
       "",
       "window-dress: the buttons without their rim",
       expect="a button has no rim of four sides", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tUI.Dress.PageSelected(b, selected)\n",
       "",
       "window-dress: every page marked as the open one",
       expect="is marked as open while", script=S)

mutate(DRESS,
       "\tif b.stud then b.stud:SetShown(selected) end\n",
       "\tif b.stud then b.stud:SetShown(false) end\n",
       "window-dress: the open page without its stud",
       expect="has no band or no stud", script=S)

mutate(DRESS,
       "\t\tlocal c = selected and UI.C.nav or UI.C.hint\n",
       "\t\tlocal c = UI.C.hint\n",
       "window-dress: the open page's second line lost in its band",
       expect="second line is still the grey of the others", script=S)

mutate(DRESS,
       "\t\tlocal c = selected and UI.C.nav or UI.C.hint\n",
       "\t\tlocal c = UI.C.nav\n",
       "window-dress: a page once open keeps its lighter line",
       expect="a page no longer open keeps the lighter second line", script=S)

mutate("Options/Window/WindowPage.lua",
       "\tsec.rule:Show()\n\tUI.Dress.PlaceSection(sec)\n",
       "\tsec.rule:Show()\n",
       "window-dress: a section's title without its stud",
       expect="a section's title has no stud", script=S)

mutate("Options/Window/WindowPage.lua",
       "\t\tif sec.stud then sec.stud:Hide() end\n",
       "",
       "window-dress: a stud left where its section was",
       expect="a stud of the page left is still up", script=S)
