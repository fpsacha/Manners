# Mutations for hunt 40, the text on the look picker's cards:
# tests/scenarios/hunt40-cards.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# picker (Options/Window/WidgetsTheme.lua), the registry (Looks/Looks.lua) or
# the pictures' tool could plausibly make, and names the scenario that objects.

T = "Options/Window/WidgetsTheme.lua"
TOOL = "tools/make_look_previews.py"
S = "runscenarios.py"

RECT = "hunt40-cards: every card has its two text overlays at the rectangles recorded for its look"
LANG = "hunt40-cards: the reason on every card is the client's own translation"
STRING = "hunt40-cards: the cards ask for no string of their own"
FACE = "hunt40-cards: each line is in the face its look writes it in on the prompt"
CHOSEN = "hunt40-cards: a font the player chose replaces the look's own face on the cards"
BAD = "hunt40-cards: a face the client cannot load gives way to its own font"
FIT = "hunt40-cards: a long German reason is drawn smaller to fit its rectangle, then cut"
GREY = "hunt40-cards: a greyed-out control greys the text, and a look with no picture has none"
TIMER = "hunt40-cards: the text is set when the page paints, not on a timer or a frame"
DATA = "hunt40-cards: every look records its two lines, completely"
HASH = "hunt40-cards: the recorded text is current with the looks, held by the hash"
BARE = "hunt40-cards: the pictures carry no text, which the cards write live"

# --- the overlay: where, what, how -----------------------------------------

mutate(T, "\t\t\t\tPlaceIcon(card)\n\t\t\t\tPlaceText(card)\n",
       "\t\t\t\tPlaceIcon(card)\n",
       "hunt40-cards: the text is not placed again when the cards are laid out at another width",
       expect=RECT, script=S)

mutate(T, "\tfs:SetPoint(\"TOPLEFT\", card.ground, \"TOPLEFT\", spec.l * w, -spec.t * h)\n",
       "\tfs:SetPoint(\"TOPLEFT\", card.ground, \"TOPLEFT\", spec.l * w, -spec.b * h)\n",
       "hunt40-cards: a line's top edge is taken from the rectangle's bottom",
       expect=RECT, script=S)

mutate(T, "\tfs:SetPoint(\"BOTTOMRIGHT\", card.ground, \"TOPLEFT\", spec.r * w, -spec.b * h)\n",
       "\tfs:SetPoint(\"BOTTOMRIGHT\", card.ground, \"TOPLEFT\", spec.r * w + 12, -spec.b * h)\n",
       "hunt40-cards: a line runs twelve units past its rectangle",
       expect=RECT, script=S)

mutate(T, "math.floor(spec.size * h + 0.5))\n\tlocal least",
       "math.floor(spec.size * 62 + 0.5))\n\tlocal least",
       "hunt40-cards: the letters are the size of the prompt's, not scaled with the picture",
       expect=RECT, script=S)

mutate(T, "\t\t\t\tfs:SetTextColor(c[1], c[2], c[3], c[4])\n",
       "\t\t\t\tfs:SetTextColor(1, 1, 1, 1)\n",
       "hunt40-cards: every line is white, whatever the look writes it in",
       expect=RECT, script=S)

mutate(T, "\t\tfs:SetShadowOffset(Offset(shadow.x * h), Offset(shadow.y * h))\n",
       "\t\tfs:SetShadowOffset(0, 0)\n",
       "hunt40-cards: the shadow has no offset",
       expect=RECT, script=S)

mutate(T, "\tlocal path, flags = LineFace(spec), spec.flags or \"\"\n",
       "\tlocal path, flags = LineFace(spec), \"\"\n",
       "hunt40-cards: the outline is dropped",
       expect=RECT, script=S)

mutate(T, "\tfs:SetWordWrap(false)\n\tlocal shadow",
       "\tfs:SetWordWrap(true)\n\tlocal shadow",
       "hunt40-cards: a line too long wraps over the next one instead of being cut",
       expect=RECT, script=S)

mutate(T, "\tfs:SetJustifyH(spec.h or \"LEFT\")\n",
       "\tfs:SetJustifyH(\"CENTER\")\n",
       "hunt40-cards: every line is centred",
       expect=RECT, script=S)

# --- what it says ----------------------------------------------------------

mutate(T, "name == \"name\" and SAMPLE_NAME or L[\"buffed you\"]",
       "name == \"name\" and SAMPLE_NAME or \"buffed you\"",
       "hunt40-cards: the reason is English on every client",
       expect=LANG, script=S)

mutate(T, "name == \"name\" and SAMPLE_NAME or L[\"buffed you\"]",
       "name == \"name\" and SAMPLE_NAME or L[\"buffed you (sample)\"]",
       "hunt40-cards: the reason is a string of the picker's own",
       expect=STRING, script=S)

mutate(T, "local SAMPLE_NAME = \"Anna Aim\"", "local SAMPLE_NAME = L[\"Anna Aim\"]",
       "hunt40-cards: the sample name is a string to translate",
       expect=STRING, script=S)

# --- the face --------------------------------------------------------------

mutate(T, "if not chosen and (not spec.latin or LATIN[ns.LOCALE or \"enUS\"]) then return spec.font end",
       "if not chosen then return spec.font end",
       "hunt40-cards: the look's own face is used on a client whose alphabet lacks it",
       expect=FACE, script=S)

mutate(T, "if not chosen and (not spec.latin or LATIN[ns.LOCALE or \"enUS\"]) then return spec.font end",
       "if (not spec.latin or LATIN[ns.LOCALE or \"enUS\"]) then return spec.font end",
       "hunt40-cards: the player's own font is overridden by the look's face",
       expect=CHOSEN, script=S)

mutate(T, "\tif spec.font then\n\t\tlocal own",
       "\tif false then\n\t\tlocal own",
       "hunt40-cards: no look's own face is ever used",
       expect=FACE, script=S)

mutate(T, "\tif not fs:SetFont(path, size, flags) or not fs:GetFont() then\n\t\tfs:SetFont(STANDARD_TEXT_FONT, size, flags)",
       "\tif not fs:SetFont(path, size, flags) or not fs:GetFont() then\n\t\tsize = size",
       "hunt40-cards: a face that will not load leaves the line with no font",
       expect=BAD, script=S)

# --- fit -------------------------------------------------------------------

mutate(T, "\twhile size > least and W.Measure(fs) > room + 0.5 do\n",
       "\twhile false and size > least and W.Measure(fs) > room + 0.5 do\n",
       "hunt40-cards: a line wider than its rectangle is never drawn smaller",
       expect=FIT, script=S)

mutate(T, "local MIN_SIZE, MIN_SHRINK = 5, 0.8", "local MIN_SIZE, MIN_SHRINK = 5, 0.3",
       "hunt40-cards: a line may shrink to a third of its size",
       expect=FIT, script=S)

mutate(T, "\twhile size > least and W.Measure(fs) > room + 0.5 do\n\t\tsize = size - 1\n",
       "\twhile size > least and W.Measure(fs) > room + 0.5 do\n\t\tsize = size - 2\n",
       "hunt40-cards: a line is drawn two units smaller than it has to be",
       expect=FIT, script=S)

mutate(T, "\tlocal room = (spec.r - spec.l) * w\n",
       "\tlocal room = w\n",
       "hunt40-cards: a line is fitted to the whole picture, not its rectangle",
       expect=FIT, script=S)

# --- greyed out, no picture ------------------------------------------------

mutate(T, "\tTintLines(card, off)\n\tcard:SetEnabled(not off)",
       "\tcard:SetEnabled(not off)",
       "hunt40-cards: a greyed-out card keeps its text in colour",
       expect=GREY, script=S)

mutate(T, "\t\t\tDressText(card, file and ns.Looks.PreviewText(key))\n",
       "\t\t\tDressText(card, ns.Looks.previewText[key])\n",
       "hunt40-cards: a look with no picture has text over the placeholder",
       expect=GREY, script=S)

mutate("Looks/Looks.lua", "function Looks.PreviewText(key)\n\tif not Looks.previews[key] then return nil end\n",
       "function Looks.PreviewText(key)\n",
       "hunt40-cards: a look with no picture is handed text rectangles",
       expect=DATA, script=S)

mutate(T, "\t\t\tfs:SetAlpha(off and 0.5 or 1)\n",
       "\t\t\tfs:SetAlpha(1)\n",
       "hunt40-cards: a greyed-out card's text is not dimmed",
       expect=GREY, script=S)

mutate(T, "\tcard.lines, card.lineSize, card.lineFace = {}, {}, {}\n",
       "\tcard.lines, card.lineSize, card.lineFace = {}, {}, {}\n\tcard:SetScript(\"OnUpdate\", function() end)\n",
       "hunt40-cards: the card has an OnUpdate",
       expect=TIMER, script=S)

# --- the data and the tool that writes it ----------------------------------

mutate("Looks/Previews.lua", "\tluxe = {\n\t\tname = {", "\tluxe_ = {\n\t\tname = {",
       "hunt40-cards: a look has no text recorded",
       expect=DATA, script=S)

mutate("Looks/Previews.lua", "\t\treason = { l = 0.31653,", "\t\treason_ = { l = 0.31653,",
       "hunt40-cards: a look records no reason line",
       expect=DATA, script=S)

mutate("Looks/Previews.lua", "\t\tname = { l = 0.28629,", "\t\tname = { l = 0.38629,",
       "hunt40-cards: a recorded rectangle is edited by hand",
       expect=HASH, script=S)

mutate("Looks/Previews.lua", "\t\tname = { l = 0.25, t = 0.2879, r = 0.86694, b = 0.51371, h = \"LEFT\", v = \"MIDDLE\", size = 0.22581, color = { 1, 0.91765, 0.67843, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 1 } }, font = \"Fonts\\\\MORPHEUS.TTF\", latin = true }",
       "\t\tname = { l = 0.25, t = 0.2879, r = 0.86694, b = 0.51371, h = \"LEFT\", v = \"MIDDLE\", size = 0.22581, color = { 1, 0.91765, 0.67843, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 1 } }, font = \"Fonts\\\\MORPHEUS.TTF\" }",
       "hunt40-cards: a face drawn only on Latin clients is recorded as drawn everywhere",
       expect=DATA, script=S)

mutate(TOOL, '        "size": (font.get("size") or 12) * scale / VIEW[1],\n',
       '        "size": (font.get("size") or 12) * scale / SIZE[1],\n',
       "hunt40-cards: the tool measures a line's size against the picture's pixels, not its units",
       expect=HASH, script=S)

mutate(TOOL, '        "t": (top - rect[3]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],\n        "h": str(',
       '        "t": (top - rect[1]) / VIEW[1], "b": (top - rect[1]) / VIEW[1],\n        "h": str(',
       "hunt40-cards: the tool measures a line's top edge from its bottom",
       expect=HASH, script=S)

mutate(TOOL, 'LINES = (("name", "name"), ("reason", "sub"))',
       'LINES = (("name", "name"), ("reason", "name"))',
       "hunt40-cards: the tool records the name's rectangle for the reason",
       expect=HASH, script=S)

mutate(TOOL, '    colour = code_colour(fs.get("text"), fs.get("textColor"))\n',
       '    colour = list(fs.get("textColor") or [1, 1, 1, 1])\n',
       "hunt40-cards: the tool ignores the colour code a name opens with",
       expect=HASH, script=S)

mutate(TOOL, '    colour[3] *= static_alpha(tree, fs)\n', '    colour[3] *= 1\n',
       "hunt40-cards: the tool leaves the frames' alpha out of a line's colour",
       expect=HASH, script=S)

mutate(TOOL, '                entry["latin"] = True\n', '                pass\n',
       "hunt40-cards: the tool does not look at the look on a client without the alphabet",
       expect=HASH, script=S)

mutate(TOOL, '    if font.get("flags"):\n        entry["flags"] = str(font["flags"])\n',
       '    if False:\n        entry["flags"] = str(font["flags"])\n',
       "hunt40-cards: the tool drops an outline",
       expect=HASH, script=S)

mutate(TOOL, '        h.update(json.dumps(written.get(key), sort_keys=True).encode("utf-8") + b"\\0")\n',
       '        h.update(b"\\0")\n',
       "hunt40-cards: the hash does not hold the recorded text",
       expect=HASH, script=S)

mutate(TOOL, "    return picture(rp, snap, hidden(snap, entry))\n", "    return picture(rp, snap, set())\n",
       "hunt40-cards: the tool draws the pictures with their text",
       expect=BARE, script=S)

mutate(TOOL, "INK = 24\n", "INK = 400\n",
       "hunt40-cards: the check for baked text cannot see any",
       expect=BARE, script=S)

mutate(TOOL, "OVERHANG = 4\n", "OVERHANG = 0\n",
       "hunt40-cards: the check lets the text no room beyond its rectangle",
       expect=BARE, script=S)
