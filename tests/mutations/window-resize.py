# Mutations for the options window's resize grip (Options/Window/Window.lua,
# UI.Resized, UI.SetWindowSize, UI.SavedSize; WindowPage.lua's width read at
# every layout; WindowDress.lua's Retile). Caught by
# tests/scenarios/window-resize.lua.

S = "runscenarios.py"

mutate("Options/Window/WindowPage.lua",
       "\tCONTENT_W = ContentWidth()\n\tlocal m = UI.Model(UI.page)\n",
       "\tlocal m = UI.Model(UI.page)\n",
       "window-resize: the rows keep the old width",
       expect="not 280 wider", script=S)

mutate("Options/Window/Window.lua",
       "\tUI.view.child:SetWidth(UI.WIDTH - UI.SIDEBAR - 13)\n",
       "",
       "window-resize: the scrolled page keeps its width",
       expect="the scrolled page is as narrow as before", script=S)

mutate("Options/Window/Window.lua",
       "\tUI.Dress.Retile()\n\tlocal now = GetTime()\n",
       "\tlocal now = GetTime()\n",
       "window-resize: the rails stretched, not tiled",
       expect="the header's rail is stretched", script=S)

mutate("Options/Window/Window.lua",
       "\tUI.WIDTH, UI.HEIGHT = math.floor(w + 0.5), math.floor(h + 0.5)\n",
       "",
       "window-resize: the window's own size never read",
       expect="the window's own size reads", script=S)

mutate("Options/Window/Window.lua",
       "\tif w == UI.MIN_W and h == UI.MIN_H then s.w, s.h = nil, nil else s.w, s.h = w, h end\n",
       "",
       "window-resize: the size not kept",
       expect="the size is not kept in the window's state", script=S)

mutate("Options/Window/Window.lua",
       "\tif w == UI.MIN_W and h == UI.MIN_H then s.w, s.h = nil, nil else s.w, s.h = w, h end\n",
       "\ts.w, s.h = w, h\n",
       "window-resize: the usual size kept as a size of its own",
       expect="the usual size is still kept", script=S)

mutate("Options/Window/Window.lua",
       "\tUI.WIDTH, UI.HEIGHT = UI.SavedSize()\n\tf:SetSize(UI.WIDTH, UI.HEIGHT)\n",
       "\tf:SetSize(UI.WIDTH, UI.HEIGHT)\n",
       "window-resize: the size left at forgotten on opening",
       expect="a window left at 960 x 700 opened at", script=S)

mutate("Options/Window/Window.lua",
       "\treturn math.max(low, math.min(high, math.floor(v + 0.5)))\n",
       "\treturn math.floor(v + 0.5)\n",
       "window-resize: no bounds on the size",
       expect="the size it was left at opens again", script=S)

mutate("Options/Window/Window.lua",
       "\tif (s.w ~= nil and not Offset(s.w)) or (s.h ~= nil and not Offset(s.h)) then s.w, s.h = nil, nil end\n",
       "",
       "window-resize: a damaged saved size kept",
       expect="a damaged saved size was kept", script=S)

mutate("Options/Window/Window.lua",
       "\tgrip:SetScript(\"OnClick\", UI.Guarded(function() UI.SetWindowSize(UI.MIN_W, UI.MIN_H) end))\n",
       "",
       "window-resize: no right click back to the usual size",
       expect="the grip has no click", script=S)

mutate("Options/Window/Window.lua",
       "\tBuildGrip(f)\n",
       "",
       "window-resize: no grip",
       expect="the window has no grip", script=S)
