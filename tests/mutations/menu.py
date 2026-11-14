# Mutations for the options window's menu: the columns a wide window flows a
# page into (Options/Window/WindowPage.lua, UI.ColumnsFor, UI.ColumnBreaks,
# FlowRun; Window.lua, UI.Resized and UI.Reflow; Widgets.lua, W.Grow;
# Layout.lua, `spans`). Caught by tests/scenarios/menu.lua.

S = "runscenarios.py"
PAGE = "Options/Window/WindowPage.lua"
WINDOW = "Options/Window/Window.lua"

# ------------------------------------------------ columns when wide

mutate(PAGE,
       "\treturn math.max(1, math.min(MAX_COLUMNS, n))\n",
       "\treturn 1\n",
       "menu: one column however wide the window",
       expect="menu: a window dragged wide flows a page's sections into two columns", script=S)

mutate(PAGE,
       "local COLUMN_GAP, MIN_COLUMN, MAX_COLUMN, MAX_COLUMNS = 28, 420, 760, 3\n",
       "local COLUMN_GAP, MIN_COLUMN, MAX_COLUMN, MAX_COLUMNS = 28, 420, 760, 2\n",
       "menu: never a third column",
       expect="1740 wide has room for 2 columns, not 3", script=S)

mutate(PAGE,
       "\t\tlocal ox, oy = (c - 1) * (width + COLUMN_GAP), y\n",
       "\t\tlocal ox, oy = 0, y\n",
       "menu: every column drawn over the first",
       expect="menu: a window dragged wide flows a page's sections into two columns", script=S)

mutate(PAGE,
       "\tlocal width = math.floor((CONTENT_W - (n - 1) * COLUMN_GAP) / n)\n",
       "\tlocal width = CONTENT_W\n",
       "menu: a column as wide as the page",
       expect="menu: a window dragged wide flows a page's sections into two columns", script=S)

mutate(PAGE,
       "\t\tif not best or tall < bestTall or (tall == bestTall and left > bestLeft) then\n",
       "\t\tif not best then\n",
       "menu: the columns cut after the first section, whatever their heights",
       expect="menu: the columns are cut where the tallest is shortest", script=S)

mutate(PAGE,
       "\t\tif not best or tall < bestTall or (tall == bestTall and left > bestLeft) then\n",
       "\t\tif not best or tall < bestTall then\n",
       "menu: between two cuts as short, the right column filled first",
       expect="heights 100,100,100 in 2 columns start at 1 2", script=S)

mutate(PAGE,
       "\t\tbottom = math.max(bottom, oy)\n",
       "\t\tbottom = oy\n",
       "menu: what is under the columns starts under the last one, not the tallest",
       expect="menu: what comes under the columns starts under the tallest", script=S)

mutate(PAGE,
       "\t\t\tif sec.span then\n\t\t\t\tFlush()\n\t\t\t\ty = FlowSpan(sec, y)\n\t\t\telse\n\t\t\t\trun[#run + 1] = sec\n\t\t\tend\n",
       "\t\t\trun[#run + 1] = sec\n",
       "menu: the line a page opens with is one section of the first column",
       expect="menu: the line a page opens with runs across the columns", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"who.now\"] = true,\n",
       "",
       "menu: Who to buff's Right now line not named as running across",
       expect="menu: the line a page opens with runs across the columns", script=S)

# ------------------------------------------------ live while the grip is dragged

mutate(WINDOW,
       "\telseif UI.Shown() then\n\t\tUI.Reflow()\n\tend\n",
       "\tend\n",
       "menu: the page waits for the next full paint while the grip is dragged",
       expect="menu: a drag re-flows the page at every change of size", script=S)

mutate(PAGE,
       "\t\tif mode ~= \"reflow\" then\n",
       "\t\tif true then\n",
       "menu: a drag asks the model which rows show, every frame",
       expect="of the model asked while the grip was held", script=S)

mutate(WINDOW,
       "\tPlaceAgain(\"reflow\")\n",
       "\tUI.painting = true\n\tpcall(UI.PaintPage)\n\tUI.painting = false\n",
       "menu: a drag reads every row again, every frame",
       expect="a row was read again while the grip was held", script=S)

mutate(WINDOW,
       "\tif view and view.top then view.height = UI.HEIGHT - view.top - UI.FOOTER end\n",
       "",
       "menu: the page's room waits for the next full paint while the grip is dragged",
       expect="the page's room is", script=S)

# ------------------------------------------------ fields that grow

mutate("Options/Window/Widgets.lua",
       "\treturn math.min(math.floor(base * 1.5), base + math.floor((width - W.USUAL) / 2))\n",
       "\treturn base\n",
       "menu: a field as narrow in a wide row as in the usual one",
       expect="menu: a field grows with a row wider than the usual page", script=S)

mutate("Options/Window/Widgets.lua",
       "\tif width <= W.USUAL then return base end\n",
       "\tif width <= 400 then return base end\n",
       "menu: a field wider in a column than in the usual window",
       expect="menu: a field grows with a row wider than the usual page", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "math.min(W.Grow(300, width), math.floor(width * 0.6))",
       "math.min(300, math.floor(width * 0.6))",
       "menu: a dropdown that never grows",
       expect="menu: a field grows with a row wider than the usual page", script=S)
