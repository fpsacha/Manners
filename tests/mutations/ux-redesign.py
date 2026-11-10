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

mutate(LAYOUT, "\t\t\t\t\t\"who.quietInTowns\",\n\t\t\t\t\t\"who.quietInInstances\",\n\t\t\t\t\t\"who.quietTargets\",\n\t\t\t\t\t\"when.hideMounted\",\n",
       "\t\t\t\t\t\"when.hideMounted\",\n",
       "ux-redesign: the place rules are not under Hold back",
       expect="ux-redesign: the place rules lead Hold back on When to offer", script=S)

mutate(LAYOUT, "\t\t\t\t\t{ \"who.ownCities\", indent = true },\n\t\t\t\t\t{ \"who.ownDungeons\", indent = true },\n"
       "\t\t\t\t\t-- A warrior's shout for himself, alone (shown to a warrior only).\n"
       "\t\t\t\t\t{ \"who.ownShout\", indent = true },\n"
       "\t\t\t\t\t-- The spells of those families you know, to leave out one by one.\n"
       "\t\t\t\t\t{ \"who.own_leave\", indent = true },\n",
       "\t\t\t\t\t{ \"who.own_leave\", indent = true },\n"
       "\t\t\t\t\t{ \"who.ownCities\", indent = true },\n\t\t\t\t\t{ \"who.ownDungeons\", indent = true },\n"
       "\t\t\t\t\t{ \"who.ownShout\", indent = true },\n",
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

# --- the words: 2, 3, 13, 14, 15, 16, 20, and the new rows -----------------------

START = "Options/Start.lua"
WORDS = "ux-redesign: the switches say what they do"

mutate(START, "\t\t\t\thidden = function() return noClassBuffs() or Quick.Asking() end,\n\t\t\t\tvalues = function() return Quick.Values(Quick.WHO) end,\n",
       "\t\t\t\thidden = noClassBuffs,\n\t\t\t\tvalues = function() return Quick.Values(Quick.WHO) end,\n",
       "ux-redesign: Offer my buff to asks again under Quick setup",
       expect="ux-redesign: Quick setup asks once", script=S)

mutate(LAYOUT, "\t\t\t\t\t{ \"general.firstDone\", buttons = true },\n",
       "\t\t\t\t\t{ \"general.firstDone\", pair = true },\n",
       "ux-redesign: Done and Skip half a page apart",
       expect="ux-redesign: Quick setup asks once", script=S)

mutate("Options/Window/WindowPage.lua", "\t\tif e.layout.buttons then\n\t\t\ty, i = PlaceButtons(list, i, y)\n\t\telseif e.layout.pair then",
       "\t\tif e.layout.pair then",
       "ux-redesign: a run of buttons stacked one under the other",
       expect="ux-redesign: Quick setup asks once", script=S)

mutate("Options/Window/WidgetsChoice.lua", "math.ceil(Widest(row)) + 40, row.matchField or 0))",
       "math.ceil(Widest(row)) + 40))",
       "ux-redesign: the two questions' dropdowns at their own widths",
       expect="ux-redesign: the two Quick setup dropdowns are one width in German", script=S)

mutate(LAYOUT, "\t\t\t\t{ key = \"general.lead\", items = {\n\t\t\t\t\t{ \"general.noBuffs\", standIn = true },\n\t\t\t\t\t\"general.howItWorks\",\n",
       "\t\t\t\t{ key = \"general.lead\", items = {\n\t\t\t\t\t{ \"general.noBuffs\", standIn = true },\n\t\t\t\t\t{ \"general.howItWorks\", lead = true },\n",
       "ux-redesign: Start here's paragraph a size up, as a heading",
       expect="ux-redesign: Start here's paragraph is body text", script=S)

mutate(START, "name = L[\"Hide all Manners messages in my chat window\"],",
       "name = L[\"Say nothing at all in chat\"],",
       "ux-redesign: the silence switch reads as the character's speech",
       expect=WORDS, script=S)

mutate("Options/When.lua", "name = L[\"Don't offer when the game hides their buffs (fights)\"],",
       "name = L[\"Only offer people whose buffs can be read\"],",
       "ux-redesign: the hidden-buffs switch in jargon",
       expect=WORDS, script=S)

mutate("Options/Who.lua", "\t\t\t\tname = RelevantLabel,\n",
       "\t\t\t\tname = L[\"Skip players it does nothing for\"],\n",
       "ux-redesign: the mana switch names nothing it holds back",
       expect=WORDS, script=S)

mutate("Options/Look.lua", "name = L[\"Colour by why they are offered\"],",
       "name = L[\"Colour marker by reason\"],",
       "ux-redesign: the colour by reason switch in jargon",
       expect=WORDS, script=S)

mutate("Options/Diagnostics.lua", "PlainSources(L[\"Passer-by distance: %s\"]:format(tostring(ns.ProximitySummary())))",
       "(L[\"Passer-by distance: %s\"]:format(tostring(ns.ProximitySummary())))",
       "ux-redesign: the distance line names the client call",
       expect="ux-redesign: the passer-by distance line names no client call", script=S)

mutate("Options/Launcher.lua", "L[\"On the prompt: |cffffffff%s|r -- %s, a passer-by\"],",
       "L[\"On the prompt: |cffffffff%s|r -- %s, nearby\"],",
       "ux-redesign: the launcher calls a passer-by nearby",
       expect="ux-redesign: the launcher calls a passer-by a passer-by", script=S)

mutate(START, "\t\t\t\t\treturn \"|cffffd100\" .. L[\"Optional: pick a key or put Manners on a bar, or just click the prompt.\"] .. \"|r\"\n",
       "\t\t\t\t\treturn \"|cffff8080\" .. L[\"Optional: pick a key or put Manners on a bar, or just click the prompt.\"] .. \"|r\"\n",
       "ux-redesign: no key said in red",
       expect="ux-redesign: no key is said in gold", script=S)

mutate("Options/Profiles.lua", "\t\tif type(option) == \"table\" then\n\t\t\tfor field, value in pairs(words) do option[field] = value end\n",
       "\t\tif false then\n",
       "ux-redesign: Profiles in the library's developer English",
       expect="ux-redesign: Profiles speaks the player's words", script=S)

mutate(START, "hidden = function() return noClassBuffs() or Quick.Match(Quick.VOICE) == \"silent\" end,",
       "hidden = noClassBuffs,",
       "ux-redesign: Stay silent then Silent.",
       expect="ux-redesign: Stay silent is not followed by Silent.", script=S)

mutate("Options/Who.lua", "hidden = function() return (tonumber(F().minLevel) or 1) > 1 end,",
       "hidden = function() return true end,",
       "ux-redesign: the level slider's 1 never explained",
       expect="ux-redesign: Skip players below level says what 1 means", script=S)

mutate("Options/Diagnostics.lua", "\t\t\t\t\treturn \"|cff888888\"\n\t\t\t\t\t\t.. L[\"Nothing to report: this character has no buffs it can put on another player.\"]",
       "\t\t\t\t\treturn \"|cffff8080\"\n\t\t\t\t\t\t.. L[\"Nothing to report: this character has no buffs it can put on another player.\"]",
       "ux-redesign: a rogue told in red that he has no buffs",
       expect="ux-redesign: a rogue's Diagnostics has no error colour", script=S)

mutate("Options/Who.lua", "\t\t\t\t\t\tif not buff.selfCast then\n",
       "\t\t\t\t\t\tif false then\n",
       "ux-redesign: Earth Shield said to be cast on yourself",
       expect="ux-redesign: Earth Shield's shaman is not told it is cast on herself", script=S)

mutate("Options/Who.lua", "\t\tif #blessings > 0 then list = table.concat(blessings, \", \") end\n",
       "",
       "ux-redesign: Beacon of Light listed among the blessings",
       expect="ux-redesign: Beacon of Light is not one of the blessings", script=S)

mutate("Options/Who.lua", " or key == \"ownDungeons\"\n",
       "\n",
       "ux-redesign: a hunter cannot hold his consumables to dungeons",
       expect="ux-redesign: a class with nothing for others has Consumables only", script=S)

# --- search, buttons, right now: 7, 8, 19 ------------------------------------------

SEARCH = "Options/Window/Search.lua"
WSEARCH = "Options/Window/WindowSearch.lua"

mutate(SEARCH, "\tif AtWordStart(entry.desc, query) then return 2 end\n",
       "\tif Has(entry.desc, query) then return 2 end\n",
       "ux-redesign: a tooltip matched inside a word",
       expect="ux-redesign: search reads tooltips by whole words", script=S)

mutate(SEARCH, "\tif find(query, \"[\\224-\\255]\") then return find(text, query, 1, true) ~= nil end\n",
       "",
       "ux-redesign: Chinese in a tooltip held to word starts",
       expect="ux-redesign: search reads tooltips by whole words", script=S)

mutate(SEARCH, "\tif entry.keywords and AtWordStart(entry.keywords, query) then return 1 end\n",
       "",
       "ux-redesign: a control's other words not searched",
       expect="ux-redesign: search reads tooltips by whole words", script=S)

mutate(LAYOUT, "\t\t[\"general.silentChat\"] = L[\"quiet mute spam\"],\n",
       "",
       "ux-redesign: quiet finds nothing",
       expect="ux-redesign: the search box finds quiet", script=S)

mutate(WSEARCH, "\tlocal found = ns.WindowSearch.Find(text, Entries(), MAX_RESULTS + 1) or {}\n",
       "\tlocal found = ns.WindowSearch.Find(text, Entries(), MAX_RESULTS) or {}\n",
       "ux-redesign: the list ends as if it were all",
       expect="ux-redesign: the search box finds quiet, says when there is more", script=S)

mutate(WSEARCH, "\t\tor L[\"Nothing matches.\"]\n",
       "\t\tor \"\"\n",
       "ux-redesign: an empty search says nothing on the classic clients",
       expect="ux-redesign: the search box finds quiet, says when there is more and when there is nothing", script=S)

mutate(WSEARCH, "\t\tlocal parent = Parent(item)\n\t\tif not parent then return end\n",
       "\t\tdo return end\n\t\tlocal parent\n",
       "ux-redesign: Line set unfindable while Say a line is off",
       expect="ux-redesign: search finds Line set while Say a line is off", script=S)

mutate("Options/Diagnostics.lua", "\t\t\t\tfunc = function() ns.addon:HandleSlash(\"selftest launch\") end,\n",
       "\t\t\t\tfunc = function() ns.addon:HandleSlash(\"selftest\") end,\n",
       "ux-redesign: the launch check button runs the short self-test",
       expect="ux-redesign: the slash-only commands have buttons", script=S)

mutate("Options/Diagnostics.lua", "\t\t\t\thidden = function() return #ns.errors <= 5 end,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "ux-redesign: every error only by command",
       expect="ux-redesign: the slash-only commands have buttons", script=S)

mutate(LAYOUT, "\t\t\t\t\t\"general.welcomeAgain\",\n",
       "",
       "ux-redesign: the welcome only by command",
       expect="every control has one place in the options window", script=S)

mutate("Options/Profiles.lua", "\t\t\thidden = function() return not (ns.ImportUndoHeld and ns.ImportUndoHeld()) end,\n",
       "\t\t\thidden = true,\n",
       "ux-redesign: the import undo only by command",
       expect="ux-redesign: Put my settings back shows while an import can be undone", script=S)

mutate("Commands.lua", "\tfunction ns.ImportUndoHeld() return lastImportUndo ~= nil and addon.db ~= nil and addon.db.profile == undoProfile end\n",
       "\tfunction ns.ImportUndoHeld() return addon.db ~= nil end\n",
       "ux-redesign: Put my settings back with nothing to undo",
       expect="ux-redesign: Put my settings back shows while an import can be undone", script=S)

mutate("Options/Shared.lua", "\tlocal queue = prompt.state and prompt.state.pickedFrom\n",
       "\tlocal queue = ns.BuildQueue()\n",
       "ux-redesign: the right-now line builds a queue every paint",
       expect="ux-redesign: the pages say who is on the prompt right now", script=S)

mutate("Options/Shared.lua", "\t\tif entry.name ~= showing.name then others = others + 1 end\n",
       "\t\tothers = others + 1\n",
       "ux-redesign: the one on the prompt counted as waiting",
       expect="ux-redesign: the pages say who is on the prompt right now", script=S)

mutate(LAYOUT, "\t\t\t\t{ key = \"when.now\", items = { \"when.rightNow\" } },\n",
       "",
       "ux-redesign: When to offer does not say who is on the prompt",
       expect="ux-redesign: the pages say who is on the prompt right now", script=S)

mutate(LAYOUT, "\t\t\t\t\t{ \"diagnostics.noErrors\", standIn = true },\n",
       "\t\t\t\t\t\"diagnostics.noErrors\",\n",
       "ux-redesign: Errors this session gone with nothing broken",
       expect="ux-redesign: the slash-only commands have buttons", script=S)
