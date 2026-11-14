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

# ------------------------------------------------ the pages, by what the player came to do

LAYOUT = "Options/Window/Layout.lua"

mutate(LAYOUT,
       "\t\t\t\titems[#items + 1] = path\n",
       "\t\t\t\titems[#items + 1] = { path, columns = 2 }\n",
       "menu: the buffs two to a row again",
       expect="menu: each buff has a row of its own", script=S)

mutate(LAYOUT,
       "\t\t\t\tif class == own and buff == mana then\n",
       "\t\t\t\tif false then\n",
       "menu: Only to players with mana under the whole list, not its buff",
       expect="menu: each buff has a row of its own", script=S)

mutate(LAYOUT,
       "\t\t\t\tif class == own and buff == melee then\n",
       "\t\t\t\tif false then\n",
       "menu: Not to casters under the whole list, not its blessing",
       expect="Not to mages, warlocks and priests is not under a paladin's Blessing of Might", script=S)

mutate(LAYOUT,
       "\t\t\t\t\titems[#items + 1] = { \"who.relevantOnly\", indent = manaAlone or nil }\n",
       "\t\t\t\t\titems[#items + 1] = \"who.relevantOnly\"\n",
       "menu: Only to players with mana level with the buff it is about",
       expect="not a step in from Divine Spirit", script=S)

mutate(PAGE,
       "\t\tif p.kind == \"toggle\" and not UI.Hidden(p.item) and SwitchedOff(p.item) then return p end\n",
       "",
       "menu: a sub-option greyed out under a switch that is off, as it was",
       expect="menu: a sub-option is not drawn under a switch that is off", script=S)

mutate(PAGE,
       "\tif e.isControl and not UI.Disabled(e.item) then return nil end\n",
       "",
       "menu: a control goes with the switch above it whatever else it serves",
       expect="the pause is gone with the /thank off", script=S)

mutate(PAGE,
       "\t\t\t\t\tif sec.entries[k].level < e.level then\n",
       "\t\t\t\t\tif sec.entries[k].level == 0 then\n",
       "menu: a row two steps in is under the switch, past the row it belongs to",
       expect="a row two steps in is not under the row one step in above it", script=S)

mutate("Options/Window/WindowSearch.lua",
       "\t\tlocal switch = Ask(UI.SwitchFor, item.path)\n",
       "\t\tlocal switch = nil\n",
       "menu: search sends the player to a row that is not drawn",
       expect="menu: search finds a sub-option under a switch that is off", script=S)

mutate(PAGE,
       "\t\tif switch and switch.path ~= path then return UI.Reveal(switch.path) end\n",
       "",
       "menu: asked for a row under a switch that is off, the window shows nothing",
       expect="asked for Sound, the window showed", script=S)

mutate(LAYOUT,
       "\t\t\t\t{ key = \"skip.lead\", title = L[\"Players to skip\"], items = {\n",
       "\t\t\t\t{ key = \"skip.lead\", items = {\n",
       "menu: Who to skip's switches under no heading",
       expect="menu: Who to buff asks who before what, and every section has a heading", script=S)

mutate(LAYOUT,
       "\t\t\t\t{ key = \"appearance.hover\", header = \"appearance.tooltipHeader\", fold = true, items = {\n",
       "\t\t\t\t{ key = \"appearance.hover\", header = \"appearance.tooltipHeader\", items = {\n",
       "menu: Look's Tooltip out of its fold",
       expect="appearance.hover is not a fold on Look", script=S)

mutate(PAGE,
       "\t\"tooltip\", \"tooltipPosition\", \"peekOnChange\" }) do\n",
       "\t\"peekOnChange\" }) do\n",
       "menu: Tooltip's fold never says it holds a change",
       expect="Tooltip's dot stays dark", script=S)

mutate(LAYOUT,
       "\t\t\t\t{ key = \"when.battle\", title = L[\"Battlegrounds and arenas\"], home = true, items = {\n",
       "\t\t\t\t{ key = \"when.battle\", title = L[\"Battlegrounds and arenas\"], items = {\n",
       "menu: the home for battlegrounds not marked as one",
       expect="when.battle is not marked as a home", script=S)

mutate(LAYOUT,
       "\t\t\t\t\t-- HOME: sharing a group with other Manners users (who buffs\n",
       "\t\t\t\t\t-- (who buffs\n",
       "menu: no home named for sharing a group with other Manners users",
       expect="menu: the homes for what is coming are in the layout", script=S)

# ------------------------------------------------ the simple view

mutate("Core.lua",
       "\t\tprofile.menuView = p.anchorCarried == true and \"offer\" or \"simple\"\n",
       "\t\tprofile.menuView = \"full\"\n",
       "menu: a new profile starts with everything, and nobody is offered the short list",
       expect="menu: a new profile starts on the short list", script=S)

mutate("Core.lua",
       "\t\tprofile.menuView = p.anchorCarried == true and \"offer\" or \"simple\"\n",
       "\t\tprofile.menuView = \"simple\"\n",
       "menu: a profile from before is put on the short list unasked",
       expect="a profile from before is stamped simple", script=S)

mutate("Core.lua",
       "\toneOf(profile, \"menuView\", { simple = true, full = true, offer = true }, \"full\")\n",
       "",
       "menu: a damaged view kept",
       expect="a damaged view was left as tiny", script=S)

mutate("Options/Shared.lua",
       "\tprofile.menuView = view == \"simple\" and \"simple\" or \"full\"\n",
       "\tprofile.menuView = view == \"simple\" and \"simple\" or \"offer\"\n",
       "menu: Not now leaves the offer up",
       expect="Not now left the view at offer", script=S)

mutate(PAGE,
       "\tif e.chrome or ns.MenuView() ~= \"simple\" then return false end\n",
       "\tif true then return false end\n",
       "menu: the simple view draws everything",
       expect="menu: the simple view draws each page's short list", script=S)

mutate(PAGE,
       "\tif type(simple) ~= \"table\" or (simple.pages or {})[e.sec.page] then return false end\n",
       "\tif type(simple) ~= \"table\" then return false end\n",
       "menu: Start here, Profiles and Diagnostics thinned out too",
       expect="general draws", script=S)

mutate(PAGE,
       "\t\t\t\tif e.bySimple then left = left + 1 end\n",
       "",
       "menu: the simple view never says what it leaves out",
       expect="does not say what its short list leaves out", script=S)

mutate(PAGE,
       "\ty = PaintChrome(chrome.offer, y, mode)\n",
       "",
       "menu: the offer of the simple view never drawn",
       expect="the offer's offer is not drawn", script=S)

mutate(PAGE,
       "\tif not UI.RowShown(path) and UI.HiddenBySimple(path) then\n\t\tns.SetMenuView(\"full\")\n\t\tUI.Refresh()\n\tend\n",
       "",
       "menu: search lands on a setting the simple view does not draw",
       expect="menu: search finds a setting the simple view leaves out", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tif side.viewItem then side.view = ns.WindowWidgets.Build(\"toggle\", side.frame, side.viewItem) end\n",
       "",
       "menu: no Simple view switch in the window",
       expect="no Simple view switch under the search box", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tlocal y, placed = side.top + PaintView(side) + 4, false\n",
       "\tlocal y, placed = side.top + 4, false\n",
       "menu: the Simple view switch built and never drawn",
       expect="the Simple view switch is not drawn under the search box", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t[\"when.hideMounted\"] = true, [\"when.manaFloor\"] = true,\n",
       "\t\t\t[\"when.manaFloor\"] = true,\n",
       "menu: Hide the prompt while mounted off the short list",
       expect="Hide the prompt while mounted is off the short list", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\tkeep[path] = true\n",
       "",
       "menu: no buff and no own buff on the short list",
       expect="a priest's Divine Spirit is off the short list", script=S)

mutate("Options/Start.lua",
       "\t\telseif key == \"menuView\" and type(value) == \"string\" then\n",
       "\t\telseif false then\n",
       "menu: the view's stamp counts as a setting somebody made",
       expect="settings-fix: an own profile only visited is filled from the shared one", script=S)

# ------------------------------------------------ the nudge to put Manners on a key

START = "Options/Start.lua"

mutate("Core.lua",
       "\t\tif ns.KeyNudge then C_Timer.After(ns.KEY_NUDGE_AFTER, function() ns.Guard(\"key reminder\", ns.KeyNudge, true) end) end\n",
       "",
       "menu: the reminder to set a key never asked for",
       expect="menu: the reminder to set a key is said once a login", script=S)

mutate("Core.lua",
       "\tif ns.KeyNudge then ns.Guard(\"key reminder\", ns.KeyNudge) end\n",
       "",
       "menu: a reminder a fight held back is never said",
       expect="not said when the fight ended", script=S)

mutate(START,
       "\tif not reminder.due or reminder.said then return false end\n",
       "\tif not reminder.due then return false end\n",
       "menu: the reminder said again at every fight's end",
       expect="said again in the same session", script=S)

mutate(START,
       "\tif InCombatLockdown() then return false end\n\treminder.said = true\n",
       "\treminder.said = true\n",
       "menu: the reminder said in a fight",
       expect="said in a fight", script=S)

mutate(START,
       "\tif char.keyReminders == nil then\n\t\tchar.keyReminders = 0\n\t\treturn false\n\tend\n",
       "",
       "menu: the reminder said on the first login, over the welcome",
       expect="the first login Manners sees a character", script=S)

mutate(START,
       "\tif (tonumber(char.keyReminders) or 0) >= Setup.REMINDERS then return \"said three times\" end\n",
       "",
       "menu: the reminder said at every login for ever",
       expect="said on a fourth login", script=S)

mutate(START,
       "\tif Setup.Key() then return \"a key is set\" end\n",
       "",
       "menu: the reminder said to a player who has a key",
       expect="a key set: said 1 time(s), not 0", script=S)

mutate(START,
       "\tif Setup.MacroMade() then return \"the Manners macro is made\" end\n",
       "",
       "menu: the reminder said to a player with Manners on a bar",
       expect="said with the Manners macro made", script=S)

mutate(START,
       "\tif profile.keyReminder == false then return \"switched off\" end\n",
       "",
       "menu: the reminder's switch does nothing",
       expect="its switch off: said 1 time(s), not 0", script=S)

mutate(START,
       "\tif profile.enabled == false then return \"Manners is off\" end\n",
       "",
       "menu: the reminder said with Manners switched off",
       expect="Manners off: said 1 time(s), not 0", script=S)

mutate(START,
       "\t\t\t\t\tif Setup.CanBind() then\n\t\t\t\t\t\treturn \"|cffffd100\" .. L[\"No key yet.\"] .. \"|r \"\n",
       "\t\t\t\t\tif false then\n\t\t\t\t\t\treturn \"|cffffd100\" .. L[\"No key yet.\"] .. \"|r \"\n",
       "menu: step 2 calls a key optional and no more, as it did",
       expect="with no key, step 2 says", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"general.bindStatus\"] = { block = true },\n",
       "",
       "menu: whether there is a key is said in a plain line",
       expect="the state is not in a block of its own", script=S)

mutate("Commands.lua",
       "\tlocal SHARE_SKIP = { keyReminder = true, enabled = true,",
       "\tlocal SHARE_SKIP = { enabled = true,",
       "menu: the reminder's switch handed on in a string of settings",
       expect="the reminder's switch travels in a string of settings", script=S)

mutate("Commands.lua",
       "\t\tif ns.Setup and ns.Setup.ReminderLine then self:Print(\"  \" .. ns.Setup.ReminderLine()) end\n",
       "",
       "menu: /manners debug silent about the key and its reminder",
       expect="/manners debug does not say why the reminder keeps quiet", script=S)
