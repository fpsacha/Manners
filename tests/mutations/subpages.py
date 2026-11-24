# The options window's sub-divisions (Options/Window/Layout.lua, `subpages`;
# WindowPage.lua, UI.SubsShown, UI.SubInView, UI.ShowSub, UI.Reveal;
# WindowChrome.lua, UI.PaintSubBar; Window.lua, PaintAll; Options/Shared.lua,
# Page.WarnAt). Each fault is caught by the scenario in
# tests/scenarios/subpages.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "subpages: "
PAGE = "Options/Window/WindowPage.lua"
CHROME = "Options/Window/WindowChrome.lua"

# A section hidden for the class still makes a sub-division.
mutate(PAGE,
       "\t\tfor _, sec in ipairs(sub.secs) do\n\t\t\tif sec.visible then\n",
       "\t\tfor _, sec in ipairs(sub.secs) do\n\t\t\tif true then\n",
       "subpages: a sub-division listed with nothing shown",
       expect=P + "a section hidden for this class gives no sub-division", script=S)

# The layout's sub-divisions never read: no bar at all.
mutate(PAGE,
       "\tfor _, def in ipairs(m.page and m.page.subpages or {}) do\n",
       "\tfor _, def in ipairs({}) do\n",
       "subpages: the layout's sub-divisions never read",
       expect=P + "a mage's pages list their sub-divisions from the layout", script=S)

# A sub-division chosen, the whole page still drawn.
mutate(PAGE,
       "\t\tsec.away = sub ~= nil and sec.sub ~= nil and sec.sub ~= sub\n",
       "\t\tsec.away = false\n",
       "subpages: a sub-division chosen draws every section",
       expect=P + "a sub-division chosen draws only its sections", script=S)

# A fold of the sub-division in view drawn shut.
mutate(PAGE,
       "\tif sec.fold and not flat then\n\t\ty = PlaceFold(sec, y)\n",
       "\tif sec.fold then\n\t\ty = PlaceFold(sec, y)\n",
       "subpages: a fold in a sub-division drawn shut",
       expect=P + "a sub-division chosen draws only its sections", script=S)

# The caption over the folds in a sub-division too.
mutate(PAGE,
       "\tif flat or not captioned then UI.ShowCaption(m, false) end\n",
       "\tif not captioned then UI.ShowCaption(m, false) end\n",
       "subpages: the fine print's caption over one sub-division",
       expect=P + "a sub-division chosen draws only its sections", script=S)

# Chosen, and the page opens wherever it was scrolled.
mutate(PAGE,
       "\tUI.view.scrollY = 0\n\tUI.Refresh()\nend\n",
       "\tUI.Refresh()\nend\n",
       "subpages: a sub-division opens scrolled",
       expect=P + "All draws the whole page again", script=S)

# The choice never kept.
mutate(PAGE,
       "\tUI.subOf[id] = key\n",
       "",
       "subpages: a chip chooses nothing",
       expect=P + "a sub-division chosen draws only its sections", script=S)

# The choice forgotten whenever the window shuts.
mutate("Options/Window/Window.lua",
       "\tUI.session.stoppedPreview = false\n\tUI.EndPeek()\n",
       "\tUI.session.stoppedPreview = false\n\tUI.subOf = {}\n\tUI.EndPeek()\n",
       "subpages: the window forgets the sub-division when it shuts",
       expect=P + "the window remembers each page's sub-division for the session", script=S)

# Search lands on the page, not on the sub-division that holds the setting.
mutate(PAGE,
       "\tif w.sec.sub then UI.subOf[w.page] = w.sec.sub.key end\n",
       "",
       "subpages: search ignores the sub-division",
       expect=P + "search opens the sub-division that holds the setting", script=S)

# The bar painted before the page is judged, and never again.
mutate("Options/Window/Window.lua",
       "\tif UI.SubsStale() then\n",
       "\tif false then\n",
       "subpages: the bar empty on a page's first paint",
       expect=P + "a mage's pages list their sub-divisions from the layout", script=S)

# No red dot on the sub-division that holds the warning.
mutate(CHROME,
       "\t\t\telseif on then\n\t\t\t\tout[w.sec.sub] = true\n",
       "\t\t\telseif on then\n",
       "subpages: no red dot on a sub-division",
       expect=P + "the red dot marks the sub-division that holds the warning", script=S)

# A warning of Who to buff left out of the sub-divisions' dots.
mutate("Options/Shared.lua",
       "\t[\"who.emptyWarning\"] = function() return HasClassBuffs() and NoSources() end,\n",
       "",
       "subpages: nobody to offer to marks no sub-division",
       expect=P + "the red dot marks the sub-division that holds the warning", script=S)

# The combat line blind to a fold drawn open in a sub-division.
mutate(CHROME,
       "\treturn not w or UI.SectionOpen(w.sec)\n",
       "\treturn not (w and w.sec.fold and not UI.State().open[w.sec.key])\n",
       "subpages: the combat line goes by the fold alone",
       expect=P + "the combat line follows the sub-division in view", script=S)

# The wheel over the bar does nothing.
mutate(CHROME,
       "\tbar:SetScript(\"OnMouseWheel\", UI.Guarded(function(_, delta) UI.ScrollBy(-(delta or 0) * 48) end))\n",
       "",
       "subpages: the wheel over the bar scrolls nothing",
       expect="the bar takes no mouse wheel", script=S)

# The page laid out behind the bar.
mutate("Options/Window/Window.lua",
       "\ttop = top + (below or 0)\n",
       "",
       "subpages: the page behind the bar",
       expect="the page starts behind the bar", script=S)
