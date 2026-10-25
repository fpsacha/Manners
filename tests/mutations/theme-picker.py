# Mutations for the look picker: tests/scenarios/theme-picker.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# picker (Options/Window/WidgetsTheme.lua), the registry's card fields
# (Looks/Looks.lua), the pictures' tool or the layout could plausibly make,
# and names the check that objects.

T = "Options/Window/WidgetsTheme.lua"
S = "runscenarios.py"

# --- one card per look ----------------------------------------------------

mutate(T, "\t\tlocal _, values = ns.Looks.Choices()\n",
       "\t\tlocal _, values = ns.Looks.Choices()\n\t\tvalues = { unpack(values, 1, 6) }\n",
       "theme-picker: only the first six looks get a card",
       expect="theme-picker: one card per registered look", script=S)

mutate(T, "\t\tlocal _, values = ns.Looks.Choices()\n",
       "\t\tlocal _, values = ns.Looks.Choices()\n\t\ttable.sort(values, function(a, b) return a > b end)\n",
       "theme-picker: the cards are not in the dropdown's order",
       expect="theme-picker: one card per registered look", script=S)

mutate("Looks/Looks.lua", "\treturn look.title or title, look.description or line\n",
       "\treturn title, line\n",
       "theme-picker: a look's own title and description are ignored",
       expect="theme-picker: one card per registered look", script=S)

mutate("Looks/Looks.lua", "\tif not Looks.previews[key] then return nil end\n", "",
       "theme-picker: a look with no picture is handed a file that is not there",
       expect="theme-picker: one card per registered look", script=S)

mutate("Looks/Looks.lua",
       'local DASHES = { " -- ", " \\226\\128\\147 ", " \\226\\128\\148 ", "\\226\\128\\148\\226\\128\\148" }',
       'local DASHES = { " -- " }',
       "theme-picker: a translated label is not split at its dash",
       expect="theme-picker: a card reads its label split", script=S)

# --- the chosen card ------------------------------------------------------

mutate(T, "\t\t\tcard.selected = now ~= nil and now == key\n",
       "\t\t\tcard.selected = i == 1\n",
       "theme-picker: the first card is always the chosen one",
       expect="theme-picker: the chosen card is the profile's style", script=S)

mutate(T, "\tcard.badge:SetShown(on and true or false)\n",
       "\tcard.badge:SetShown(false)\n",
       "theme-picker: the chosen card has no tick",
       expect="theme-picker: the chosen card is the profile's style", script=S)

mutate(T, "\tShowAll(card.inner, on and true or false)\n",
       "\tShowAll(card.inner, false)\n",
       "theme-picker: the chosen card has no gold edge",
       expect="theme-picker: the chosen card is the profile's style", script=S)

# --- the pointer ----------------------------------------------------------

mutate(T, "local function Entered(card)\n\tcard.hover = true\n",
       "local function Entered(card)\n\tcard.hover = false\n",
       "theme-picker: a card under the pointer does not light up",
       expect="theme-picker: the card under the pointer lights up", script=S)

mutate(T, "local function Left(card)\n\tcard.hover = false\n",
       "local function Left(card)\n\tcard.hover = true\n",
       "theme-picker: a card stays lit after the pointer leaves",
       expect="theme-picker: the card under the pointer lights up", script=S)

# --- a click --------------------------------------------------------------

mutate(T, "\tW.Apply(row, card.key)\n",
       "\tW.Apply(row, Bind().Value(row.item))\n",
       "theme-picker: a click applies the look already chosen",
       expect="theme-picker: a click sets the style", script=S)

mutate(T, "\tif W.Off(row) or not card.key or card.selected then return end\n",
       "\tif not card.key or card.selected then return end\n",
       "theme-picker: a greyed-out card takes the click",
       expect="theme-picker: a greyed-out control cannot be clicked", script=S)

mutate(T, "\tif W.Off(row) or not card.key or card.selected then return end\n",
       "\tif W.Off(row) or not card.key then return end\n",
       "theme-picker: the chosen card restyles the prompt again",
       expect="theme-picker: a click sets the style", script=S)

mutate(T, "\tcard.shot:SetDesaturated(off and true or false)\n",
       "\tcard.shot:SetDesaturated(false)\n",
       "theme-picker: a greyed-out card is not greyed",
       expect="theme-picker: a greyed-out control cannot be clicked", script=S)

mutate(T, "\tW.Apply(row, card.key)\nend\n",
       "\tW.Apply(row, card.key)\n\tns.Prompt:GetButton():SetAttribute(\"type1\", nil)\nend\n",
       "theme-picker: a click disarms the secure button",
       expect="theme-picker: a click in a fight is kept and flushed when it ends, touching nothing secure", script=S)

mutate(T, "\tW.Apply(row, card.key)\nend\n",
       "\tW.Apply(row, card.key)\n\tns.Prompt:GetButton():SetAttribute(\"macrotext1\", \"\")\nend\n",
       "theme-picker: a click empties the secure button's macro",
       expect="theme-picker: choosing a look never changes the secure button's attributes", script=S)

# --- nothing secure, no timers --------------------------------------------

mutate(T, '\tlocal card = CreateFrame("Button", nil, row.frame)\n',
       '\tlocal card = CreateFrame("Button", nil, row.frame, "SecureActionButtonTemplate")\n',
       "theme-picker: a card is a secure button",
       expect="theme-picker: nothing in the picker is secure, runs on a timer, or hangs off the prompt", script=S)

mutate(T, "\tcard.row = row\n\tcard.fill",
       "\tcard.row = row\n\tcard:SetScript(\"OnUpdate\", function() end)\n\tcard.fill",
       "theme-picker: a card runs an OnUpdate",
       expect="theme-picker: nothing in the picker is secure, runs on a timer, or hangs off the prompt", script=S)

mutate(T, '\tcard.badge:SetPoint("TOPRIGHT", card.ground, "TOPRIGHT", -4, -4)\n',
       '\tcard.badge:SetPoint("TOPRIGHT", ns.Prompt:GetButton(), "TOPRIGHT", -4, -4)\n',
       "theme-picker: the tick is anchored to the prompt",
       expect="theme-picker: nothing in the picker is secure, runs on a timer, or hangs off the prompt", script=S)

# --- layout ---------------------------------------------------------------

mutate(T, "local MIN_WIDTH, MAX_COLUMNS = 150, 3\n", "local MIN_WIDTH, MAX_COLUMNS = 150, 6\n",
       "theme-picker: up to six cards to a row",
       expect="theme-picker: the cards fit the page", script=S)

mutate(T, "\t\t\ty = y + tallest + GAP\n", "\t\t\ty = y + tallest - 8\n",
       "theme-picker: a row of cards starts inside the one above",
       expect="theme-picker: the cards fit the page", script=S)

mutate(T, "\t\tlocal base = math.floor((width - (cols - 1) * GAP) / cols)\n",
       "\t\tlocal base = math.floor(width / cols)\n",
       "theme-picker: the cards run past the page's width",
       expect="theme-picker: the cards fit the page", script=S)

mutate(T, "\t\t\t\tx = x + s.w + GAP\n", "\t\t\t\tx = x + s.w\n",
       "theme-picker: no gap between two cards",
       expect="theme-picker: the cards fit the page", script=S)

mutate("Options/Window/Layout.lua", '\t\t\t\t\t{ "appearance.style", widget = "themes" },\n',
       '\t\t\t\t\t{ "appearance.style" },\n',
       "theme-picker: Look draws the dropdown, not the gallery",
       expect="theme-picker: the Look page leads with the gallery", script=S)

# --- search and the fallback ----------------------------------------------

mutate("Options/Look.lua",
       '\t\t\t\tdesc = L["Pick a theme for the prompt. Click a card to switch to it at once."],\n', "",
       "theme-picker: the control says nothing a search for theme finds",
       expect="theme-picker: the search finds the picker", script=S)

mutate("Options/Look.lua", "\t\t\t\tvalues = (ns.Looks.Choices()),\n",
       "\t\t\t\tvalues = { glass = L[\"Glass -- dark panel, soft shadow\"] },\n",
       "theme-picker: the dropdown offers only Glass",
       expect="theme-picker: the dropdown is still the model's control", script=S)

mutate("Options/Look.lua", "\t\t\t\tsorting = select(2, ns.Looks.Choices()),\n",
       "\t\t\t\tsorting = { \"glass\" },\n",
       "theme-picker: the dropdown's order lists only Glass",
       expect="theme-picker: the dropdown is still the model's control", script=S)

# --- the pictures ---------------------------------------------------------

mutate("Looks/Luxe.lua", "local SPINE_X = 6\n", "local SPINE_X = 7\n",
       "theme-picker: Luxe changes and its picture is not drawn again",
       expect="theme-picker: the pictures were drawn from the looks as they are now", script=S)

mutate("Looks/Previews.lua", "\tluxe = true,\n", "",
       "theme-picker: a look has no picture",
       expect="theme-picker: every look has a picture", script=S)

mutate("tools/make_look_previews.py", "SIZE = (256, 64)\n", "SIZE = (256, 128)\n",
       "theme-picker: the pictures are another size than the files",
       expect="theme-picker: the pictures were drawn from the looks as they are now", script=S)

mutate("tools/make_look_previews.py", "VIEW = (248, 62)\n", "VIEW = (240, 60)\n",
       "theme-picker: the view the pictures are cut from changed and they were not drawn again",
       expect="theme-picker: the pictures were drawn from the looks as they are now", script=S)

# --- the strings ----------------------------------------------------------

mutate("Locales/koKR.lua", 'L["Glass"] = "유리"\n', "",
       "theme-picker: a look's name has no Korean",
       expect="theme-picker: every string the picker shows has all eight translations", script=S)

mutate("Locales/deDE.lua",
       'L["Pick a theme for the prompt. Click a card to switch to it at once."] = "Wählt einen Stil für die Anzeige. Ein Klick auf eine Karte wechselt sofort dazu."\n',
       "",
       "theme-picker: the picker's tooltip has no German",
       expect="theme-picker: every string the picker shows has all eight translations", script=S)
