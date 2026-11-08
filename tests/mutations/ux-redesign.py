# Mutations for round 37, the options window redesign:
# tests/scenarios/ux-redesign.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back what the
# round 36 audit found, and names the scenario that objects.

S = "runscenarios.py"
THEME = "Options/Window/WidgetsTheme.lua"

# --- 1: the Luxe card's tag ------------------------------------------------

mutate(THEME, "\tHidePill(card, #pill.layers + 1)\n\t-- Slices made here, at layout, after the card was last painted: tinted now,\n"
       "\t-- or they stay the file's own white until the pointer passes over the card.\n"
       "\tTintLines(card, card.row and card.row.off)\n",
       "\tHidePill(card, #pill.layers + 1)\n",
       "ux-redesign: the Luxe tag's slices are left untinted at layout",
       expect="ux-redesign: the Luxe card's tag is tinted the first time the page is drawn", script=S)

# --- the layout moves: 4, 5, 9, 10, 11, 17, 18 -------------------------------

LAYOUT = "Options/Window/Layout.lua"

mutate(LAYOUT, "\t\t\t\t\t\"who.quietInTowns\",\n\t\t\t\t\t\"who.quietInInstances\",\n\t\t\t\t\t\"when.hideMounted\",\n",
       "\t\t\t\t\t\"when.hideMounted\",\n",
       "ux-redesign: the place rules are not under Hold back",
       expect="ux-redesign: the place rules lead Hold back on When to offer", script=S)

mutate(LAYOUT, "\t\t\t\t\t{ \"who.ownCities\", indent = true },\n\t\t\t\t\t{ \"who.ownDungeons\", indent = true },\n"
       "\t\t\t\t\t-- The spells of those families you know, to leave out one by one.\n"
       "\t\t\t\t\t{ \"who.own_leave\", indent = true },\n",
       "\t\t\t\t\t{ \"who.own_leave\", indent = true },\n"
       "\t\t\t\t\t{ \"who.ownCities\", indent = true },\n\t\t\t\t\t{ \"who.ownDungeons\", indent = true },\n",
       "ux-redesign: the place switches read as items of Never remind me about",
       expect="ux-redesign: the Myself place switches come before Never remind me about", script=S)

mutate(LAYOUT, "\t\t\t\t\t\"when.verifiedOnly\",\n\t\t\t\t} },\n\t\t\t\t{ key = \"when.self\", header = \"when.selfHeader\", items = {\n",
       "\t\t\t\t\t\"when.verifiedOnly\",\n",
       "ux-redesign: your own top-ups back under other people's",
       expect="ux-redesign: your own top-ups have a section of their own", script=S)

mutate("Options/When.lua", "hidden = function() return (tonumber(F().selfLead) or 0) ~= 0 end,",
       "hidden = function() return true end,",
       "ux-redesign: the slider's 0 never explained",
       expect="ux-redesign: your own top-ups have a section of their own", script=S)

mutate("Options/When.lua", "selfHeader = { type = \"header\", name = L[\"My own buffs\"], order = 6 },",
       "selfHeader = { type = \"header\", name = L[\"My own buffs\"], order = 3.55 },",
       "ux-redesign: the old dialog's My own buffs heading over other people's notes",
       expect="ux-redesign: your own top-ups have a section of their own", script=S)

mutate(LAYOUT, "\t\t\t\t\t\"who.kingsFirst\",\n\t\t\t\t\t{ composite = \"order\"",
       "\t\t\t\t\t{ composite = \"order\"",
       "ux-redesign: Kings first not on top of the order list",
       expect="ux-redesign: Kings first sits on top of the Buff order list", script=S)

mutate(LAYOUT, "{ key = \"appearance.queue\", title = L[\"Waiting list\"], items = {",
       "{ key = \"appearance.queue\", title = L[\"Waiting list\"], fold = true, items = {",
       "ux-redesign: the waiting list folded away",
       expect="ux-redesign: the waiting list has its own section above the folds", script=S)

mutate(LAYOUT, "\t\t\t\t\t\"diagnostics.reportHint\",\n",
       "",
       "ux-redesign: Reporting a bug says nothing of which button",
       expect="ux-redesign: Reporting a bug says which button to press", script=S)

mutate(LAYOUT, "title = L[\"Position\"]",
       "title = L[\"Where it sits\"]",
       "ux-redesign: Where it sits twice in a row",
       expect="ux-redesign: Look's place section is titled Position", script=S)

# --- greyed, and why: 3, 4, 6, 12 ----------------------------------------------

WIDGETS = "Options/Window/Widgets.lua"

mutate(WIDGETS, "\th = PlaceOffNote(row, width, h)\n",
       "",
       "ux-redesign: a greyed control never says why",
       expect="ux-redesign: a greyed control says which switch greys it", script=S)

mutate(WIDGETS, "\tif off then GameTooltip:AddLine(off, T.hint[1], T.hint[2], T.hint[3], true) end\n",
       "",
       "ux-redesign: the tooltip of a greyed control does not say why",
       expect="ux-redesign: a greyed control says which switch greys it", script=S)

mutate(WIDGETS, "\tif not (row.off and item and item.def and item.path) then return nil end\n",
       "\tif not (item and item.def and item.path) then return nil end\n",
       "ux-redesign: the reason shows on a control that is not greyed",
       expect="ux-redesign: a greyed control says which switch greys it", script=S)

mutate(LAYOUT, "\t\t[\"who.groupBuffsUse\"] = function() return L[\"Needs %s ticked.\"]:format(NameOf(\"who.group\")) end,\n",
       "",
       "ux-redesign: Use group buffs greyed with no word of why",
       expect="ux-redesign: a greyed control says which switch greys it", script=S)

mutate("Options/Start.lua", "\t\t\t\tdisabled = function() return ns.db.profile.silentChat == true end,\n",
       "",
       "ux-redesign: both chat switches can be on",
       expect="ux-redesign: the chat switch greys while all Manners lines are hidden", script=S)

mutate("Options/Who.lua", "disabled = function() return not S().strangers or F().quietInTowns == true end,",
       "disabled = function() return not S().strangers end,",
       "ux-redesign: Only in cities and inns live under Offer nothing in cities and inns",
       expect="ux-redesign: Only in cities and inns greys under Offer nothing", script=S)

mutate(LAYOUT, "\t\t\tif db and db.filters.quietInTowns == true then\n",
       "\t\t\tif false then\n",
       "ux-redesign: Only in cities and inns greyed says the wrong switch",
       expect="ux-redesign: Only in cities and inns greys under Offer nothing", script=S)

mutate("Options/Advanced.lua", "name = L[\"Reset this page\"],",
       "name = L[\"Put these back to default\"],",
       "ux-redesign: the footer's reset reads as before",
       expect="ux-redesign: the footer's reset reads Reset this page", script=S)
