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

# --- the live icon ----------------------------------------------------------

PLACE = "theme-picker: every card has an icon over its picture"
OWN = "theme-picker: the icon is the player's own buff, cropped as the prompt crops it"
NONE = "theme-picker: a class with no buff for others wears its own learned buff, else the question mark"
SET = "theme-picker: the icon is set when the page paints, and again once the client knows it"
MASK = "theme-picker: round looks get their own round mask on the icon, square looks none"
GREY = "theme-picker: a greyed-out control greys the icons too, and a look with no picture has none"
DATA = "theme-picker: the icon data covers every registered look, and is held current by the hash"
HASH = "theme-picker: the pictures were drawn from the looks as they are now"

mutate(T, '\ticon:SetPoint("TOPLEFT", card.ground, "TOPLEFT", at.l * w, -at.t * h)\n',
       '\ticon:SetPoint("TOPLEFT", card.ground, "TOPLEFT", at.l * w, -at.t * w)\n',
       "theme-picker: the icon's top edge is measured in the picture's width",
       expect=PLACE, script=S)

mutate(T, '\ticon:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", at.r * w, -at.b * h)\n',
       '\ticon:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", at.r * w, -at.t * h)\n',
       "theme-picker: the icon is as short as its top edge",
       expect=PLACE, script=S)

mutate(T, "\t\t\t\tcard.picW, card.picH = s.inner, s.shotH\n\t\t\t\tPlaceIcon(card)\n",
       "\t\t\t\tcard.picW, card.picH = s.inner, s.shotH\n",
       "theme-picker: the icon is not placed again when the cards are laid out at another width",
       expect=PLACE, script=S)

mutate(T, "\tcard.iconFile = file\n\ticon:SetTexture(file)\n\tlocal crop = at.crop or CROP\n"
          "\ticon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])\n\tShapeIcon(card, at)\n\tPlaceIcon(card)\n",
       "\tcard.iconFile = file\n\ticon:SetTexture(file)\n\tlocal crop = at.crop or CROP\n"
       "\ticon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])\n\tShapeIcon(card, at)\n",
       "theme-picker: a card given another look keeps its icon where the last one was",
       expect=PLACE, script=S)

mutate(T, "local function BuffIcon()\n",
       "local function BuffIcon()\n\tif true then return UNKNOWN end\n",
       "theme-picker: every card wears the question mark",
       expect=OWN, script=S)

mutate(T, "\tfor _, buff in ipairs(ns.CastableBuffs()) do\n\t\tlocal icon = file(ns.BuffInfo(buff))\n",
       "\tfor _, buff in ipairs(ns.CastableBuffs()) do\n\t\tlocal icon = 135932 or file(ns.BuffInfo(buff))\n",
       "theme-picker: every card wears the mock's one icon, whatever the buff",
       expect=OWN, script=S)

mutate(T, "\tlocal own = ns.caps.own\n", "\tlocal own = nil\n",
       "theme-picker: a class with only an aspect of its own gets the question mark",
       expect=NONE, script=S)

mutate(T, "\treturn UNKNOWN\nend\n", "\treturn 135932\nend\n",
       "theme-picker: a character with no buff wears a mage's spell",
       expect=NONE, script=S)

mutate(T, "\tlocal crop = at.crop or CROP\n", "\tlocal crop = { 0, 1, 0, 1 }\n",
       "theme-picker: the icon is not cropped as the prompt crops it",
       expect=OWN, script=S)

mutate(T, "\ticon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])\n", "",
       "theme-picker: the icon is not cropped at all",
       expect=OWN, script=S)

mutate(T, "\tlocal round = at and at.round and at.mask and card.CreateMaskTexture and icon.AddMaskTexture\n",
       "\tlocal round = nil\n",
       "theme-picker: a round look's icon is left square",
       expect=MASK, script=S)

mutate(T, "\tlocal round = at and at.round and at.mask and card.CreateMaskTexture and icon.AddMaskTexture\n",
       "\tlocal round = at and card.CreateMaskTexture and icon.AddMaskTexture\n",
       "theme-picker: a square look's icon is masked as well",
       expect=MASK, script=S)

mutate(T, "\telseif card.masked then\n", "\telseif false then\n",
       "theme-picker: a card that stops being round keeps its mask",
       expect=MASK, script=S)

mutate(T, "\t\tcard.mask:SetAllPoints(icon)\n", "\t\tcard.mask:SetAllPoints(card)\n",
       "theme-picker: the mask covers the card and not the icon",
       expect=MASK, script=S)

mutate(T, "\tcard.icon:SetDesaturated(off and true or false)\n", "\tcard.icon:SetDesaturated(false)\n",
       "theme-picker: a greyed-out card's icon stays in colour",
       expect=GREY, script=S)

mutate(T, "\tcard.icon:SetAlpha(off and 0.5 or 1)\n", "\tcard.icon:SetAlpha(1)\n",
       "theme-picker: a greyed-out card's icon is not dimmed",
       expect=GREY, script=S)

mutate(T, "\t\tcard.iconFile = nil\n\t\ticon:Hide()\n", "\t\tcard.iconFile = nil\n",
       "theme-picker: a look with no picture has an icon over its placeholder",
       expect=GREY, script=S)

mutate(T, "\t\tlocal spell = BuffIcon()\n", "\t\tlocal spell = row.spell or BuffIcon()\n\t\trow.spell = spell\n",
       "theme-picker: the icon is worked out once and never again",
       expect=SET, script=S)

mutate(T, "\tcard.iconFile = file\n\ticon:SetTexture(file)\n",
       "\tcard.iconFile = file\n\ticon:SetTexture(file)\n\tC_Timer.After(1, function() end)\n",
       "theme-picker: painting a card parks a timer",
       expect=SET, script=S)

mutate(T, '\ticon:SetPoint("TOPLEFT", card.ground, "TOPLEFT", at.l * w, -at.t * h)\n',
       '\ticon:SetPoint("TOPLEFT", ns.Prompt:GetButton(), "TOPLEFT", at.l * w, -at.t * h)\n',
       "theme-picker: the icon is anchored to the prompt",
       expect="theme-picker: nothing in the picker is secure, runs on a timer, or hangs off the prompt", script=S)

mutate("Looks/Looks.lua", "function Looks.PreviewIcon(key)\n\tif not Looks.previews[key] then return nil end\n",
       "function Looks.PreviewIcon(key)\n",
       "theme-picker: a look with no picture is handed an icon rectangle",
       expect=DATA, script=S)

# --- the icon data, and the tool that writes it -----------------------------

mutate("Looks/Previews.lua", "\tluxe = { l = ", "\tluxe_ = { l = ",
       "theme-picker: a look has no icon rectangle",
       expect=DATA, script=S)

mutate("Looks/Previews.lua", "\ttoast = { l = 0.08554,", "\ttoast = { l = 0.09554,",
       "theme-picker: a recorded icon rectangle is edited by hand",
       expect=HASH, script=S)

mutate("Looks/Previews.lua", "round = true, mask = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Toast\\\\Toast_IconMask\", ",
       "round = false, ",
       "theme-picker: a round look is recorded square",
       expect=MASK, script=S)

mutate("Looks/Previews.lua", "Textures\\\\Toast\\\\Toast_IconMask\"", "Textures\\\\Toast\\\\Toast_IconMaskX\"",
       "theme-picker: a round look's mask is a file that is not shipped",
       expect=MASK, script=S)

mutate("tools/make_look_previews.py", '"t": (top - rect[3]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],',
       '"t": (top - rect[1]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],',
       "theme-picker: the tool measures an icon's top edge from its bottom",
       expect=HASH, script=S)

mutate("tools/make_look_previews.py", "ROUND_BELOW = 0.85\n", "ROUND_BELOW = 0.5\n",
       "theme-picker: the tool finds no look round",
       expect=HASH, script=S)

mutate("tools/make_look_previews.py", '    crop = icon.get("texCoord")\n', '    crop = None\n',
       "theme-picker: the tool does not record the crop",
       expect=HASH, script=S)

mutate("tools/make_look_previews.py", "    cx, cy = (brect[0] + brect[2]) / 2, (brect[1] + brect[3]) / 2 + (snap.get(\"lift\") or 0)\n    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2\n    entry = {",
       "    cx, cy = (brect[0] + brect[2]) / 2 + 3, (brect[1] + brect[3]) / 2 + (snap.get(\"lift\") or 0)\n    left, top = cx - VIEW[0] / 2, cy + VIEW[1] / 2\n    entry = {",
       "theme-picker: the tool measures from a view three units off the picture's",
       expect=HASH, script=S)
