# Mutations for hunt 41, the tag round the reason on the Luxe card:
# tests/scenarios/hunt41-cards.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# picker (Options/Window/WidgetsTheme.lua), the recording (Looks/Previews.lua)
# or the tool that writes it could plausibly make, and names the scenario that
# objects.

T = "Options/Window/WidgetsTheme.lua"
TOOL = "tools/make_look_previews.py"
S = "runscenarios.py"

HUG = "hunt41-cards: the Luxe tag hugs the live reason in every language"
WORDS = "hunt41-cards: the Luxe tag is as wide as its words, not the English ones"
OWN = "hunt41-cards: the recorded tag is the one the live Luxe prompt wears, and no other look wears one"
GREY = "hunt41-cards: a greyed-out card greys its tag with its words"
DATA = "hunt41-cards: the tag is recorded completely"
# The tool's own checks, run by hunt 40's scenarios: a tool that records the
# tag wrongly no longer matches the hash, and one that bakes it into the
# pictures no longer matches the shipped files.
HASH = "hunt40-cards: the recorded text is current with the looks, held by the hash"
BARE = "hunt40-cards: the pictures carry no text, which the cards write live"

# --- the picker: where the tag is drawn ------------------------------------

mutate(T, "\tlocal right = spec.l * w + math.min(W.Measure(fs), room) + pill.tail * h\n",
       "\tlocal was = fs:GetText()\n\tfs:SetText(\"buffed you\")\n\tlocal english = W.Measure(fs)\n\tfs:SetText(was)\n"
       "\tlocal right = spec.l * w + math.min(english, room) + pill.tail * h\n",
       "hunt41-cards: the tag is the English words' width, whatever the words say",
       expect=WORDS, script=S)

mutate(T, "\tlocal right = spec.l * w + math.min(W.Measure(fs), room) + pill.tail * h\n",
       "\tlocal right = spec.l * w + 50 * h / 62 + pill.tail * h\n",
       "hunt41-cards: the tag is the width the prompt's words have, not the card's",
       expect=HUG, script=S)

mutate(T, "\tlocal left = spec.l * w - pill.lead * h\n",
       "\tlocal left = spec.l * w\n",
       "hunt41-cards: the tag starts at the words, with no lead",
       expect=HUG, script=S)

mutate(T, "\tlocal right = spec.l * w + math.min(W.Measure(fs), room) + pill.tail * h\n",
       "\tlocal right = spec.l * w + math.min(W.Measure(fs), room)\n",
       "hunt41-cards: the tag ends at the words, with no tail",
       expect=HUG, script=S)

mutate(T, "\tlocal top, bottom = pill.t * h, pill.b * h\n",
       "\tlocal top, bottom = pill.t * w, pill.b * w\n",
       "hunt41-cards: the tag's edges scale with the picture's width",
       expect=HUG, script=S)

mutate(T, "\tlocal cap = (pill.cap or 0.5) * height\n",
       "\tlocal cap = (pill.cap or 0.5) * height * 2\n",
       "hunt41-cards: the caps are the tag's whole height wide",
       expect=HUG, script=S)

mutate(T, "\tif name == \"reason\" then PlacePill(card, spec, fs, room) end\n",
       "",
       "hunt41-cards: the tag is never drawn",
       expect=HUG, script=S)

mutate(T, "\t\tt:SetTexCoord(CUTS[j][1], CUTS[j][2], 0, 1)\n",
       "\t\tt:SetTexCoord(0, 1, 0, 1)\n",
       "hunt41-cards: every slice is the whole file",
       expect=HUG, script=S)

mutate(T, "\t\t\tt:SetTexture(layer.file)\n",
       "\t\t\tt:SetTexture(pill.layers[1].file)\n",
       "hunt41-cards: every layer is drawn with the first layer's file",
       expect=HUG, script=S)

mutate(T, "\t\t\t\t\tt:SetVertexColor(c[1], c[2], c[3], c[4])\n",
       "\t\t\t\t\tt:SetVertexColor(1, 1, 1, 1)\n",
       "hunt41-cards: the tag is white",
       expect=HUG, script=S)

mutate(T, "\t\tlocal t = card:CreateTexture(nil, \"ARTWORK\", nil, math.min(7, PILL_LEVEL + i - 1))\n",
       "\t\tlocal t = card:CreateTexture(nil, \"ARTWORK\", nil, 2)\n",
       "hunt41-cards: the tag is drawn under the icon",
       expect=HUG, script=S)

# --- the picker: which looks, and greyed out --------------------------------

mutate(T, "\tlocal pill = spec.pill\n\tif not pill then\n\t\tHidePill(card)\n\t\treturn\n\tend\n",
       "\tlocal pill = spec.pill or ns.Looks.previewText.luxe.reason.pill\n",
       "hunt41-cards: every look wears Luxe's tag",
       expect=OWN, script=S)

mutate(T, "\t\t\t\t\tlocal grey = Grey(c)\n\t\t\t\t\tt:SetVertexColor(grey, grey, grey, c[4])\n",
       "\t\t\t\t\tt:SetVertexColor(c[1], c[2], c[3], c[4])\n",
       "hunt41-cards: a greyed-out card keeps its tag in colour",
       expect=GREY, script=S)

mutate(T, "\t\t\tt:SetAlpha(off and 0.5 or 1)\n\t\tend\n\tend\nend\n",
       "\t\t\tt:SetAlpha(1)\n\t\tend\n\tend\nend\n",
       "hunt41-cards: a greyed-out card's tag is not dimmed",
       expect=GREY, script=S)

# --- the recording ---------------------------------------------------------

mutate("Looks/Previews.lua", "lead = 0.12097, tail = 0.12097,", "lead = 0.12097, tail = 0.22097,",
       "hunt41-cards: the tag's tail is edited by hand",
       expect=OWN, script=S)

mutate("Looks/Previews.lua", "Textures\\\\Luxe\\\\Luxe_PillEdge\", color = { 1, 0.78, 0.3, 0.5 }",
       "Textures\\\\Luxe\\\\Luxe_PillEdge\", color = { 1, 1, 1, 0.5 }",
       "hunt41-cards: the tag's edge is recorded white",
       expect=OWN, script=S)

mutate("Looks/Previews.lua", "Textures\\\\Luxe\\\\Luxe_Pill\", color = { 0.2, 0.156, 0.06, 0.9 }",
       "Textures\\\\Luxe\\\\Luxe_Fill\", color = { 0.2, 0.156, 0.06, 0.9 }",
       "hunt41-cards: the tag's fill is a file the addon does not ship",
       expect=DATA, script=S)

# --- the tool that writes it ------------------------------------------------

mutate(TOOL, '        "lead": (rect[0] - frect[0]) / VIEW[1], "tail": (frect[2] - rect[0] - words) / VIEW[1],\n',
       '        "lead": (rect[0] - frect[0]) / VIEW[1], "tail": (frect[2] - rect[0] - words) / VIEW[0],\n',
       "hunt41-cards: the tool measures the tag's tail against the picture's width",
       expect=HASH, script=S)

mutate(TOOL, '        "t": (top - frect[3]) / VIEW[1], "b": (top - frect[1]) / VIEW[1],\n        "lead"',
       '        "t": (top - frect[3]) / VIEW[1], "b": (top - frect[3]) / VIEW[1],\n        "lead"',
       "hunt41-cards: the tool records the tag's bottom edge from its top",
       expect=HASH, script=S)

mutate(TOOL, "                pill = pill_entry(snap, key, which)\n                if pill:\n                    entry[\"pill\"] = pill\n",
       "",
       "hunt41-cards: the tool records no tag",
       expect=HASH, script=S)

mutate(TOOL, "            if lines[name].get(\"pill\"):\n                _, slices = tag_frame(snap, which)\n                out.update(r[\"id\"] for r in (slices or []))\n",
       "",
       "hunt41-cards: the tool bakes the tag into the pictures",
       expect=BARE, script=S)
