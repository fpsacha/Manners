# Mutations for the prompt's readability: tests/scenarios/look2.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each one puts back a mistake
# the readability work could plausibly make, and names the line in look2.lua
# that has to be the one to object.

# White text on every panel again, whatever the panel colour.
mutate("Prompt/Text.lua",
       "\t\tif ink.light then r, g, b = 1, 1, 1 else r, g, b = 0.08, 0.08, 0.10 end\n",
       "\t\tr, g, b = 1, 1, 1\n",
       "the name white on a light panel",
       expect="reads on a cream panel: the name is drawn in",
       script="runscenarios.py")

# The light-or-dark question never asked: every panel judged dark.
mutate("Prompt/Text.lua",
       "\tink.light = onWhite >= onBlack\n",
       "\tink.light = true\n",
       "every panel taken for a dark one",
       expect="reads on a white panel",
       script="runscenarios.py")

# The contrast floor gone: a grey that does not read on the panel kept as is.
mutate("Prompt/Text.lua",
       "\tif Contrast(r, g, b) >= minimum then return r, g, b end\n",
       "\tdo return r, g, b end\n",
       "no colour held to a contrast",
       expect="the reason line is drawn in",
       script="runscenarios.py")

# The colours inside the text left as they came: a priest's white on cream.
mutate("Prompt/Text.lua",
       '\treturn (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", LegibleCode))\n',
       "\treturn text\n",
       "class colours not made legible",
       expect="class colour in the name",
       script="runscenarios.py")

# The rule reaching the default panel: a grey pushed brighter than it was.
mutate("Prompt/Text.lua",
       "\tpanel = { sub = { 0.60, 0.61, 0.68 },",
       "\tpanel = { sub = { 0.70, 0.71, 0.78 },",
       "the default panel's reason line moved",
       expect="the reason line's colour is",
       script="runscenarios.py")

# The player's own text colour overridden by the automatic one.
mutate("Prompt/Text.lua",
       "\tif ChosenTextColor(p.fontColor) then\n",
       "\tif false then\n",
       "a picked text colour ignored",
       expect="red text picked",
       script="runscenarios.py")

# The Minimal look without its outline.
mutate("Prompt/Text.lua",
       '\tlocal outline = bare and "OUTLINE" or ""\n',
       '\tlocal outline = ""\n',
       "minimal text with no outline",
       expect="has no outline over the world",
       script="runscenarios.py")

# The Minimal look's lines back to the dim panel greys.
mutate("Prompt/Text.lua",
       "\tlocal greys = bare and GREYS.bare or GREYS.panel\n",
       "\tlocal greys = GREYS.panel\n",
       "minimal text in the dim greys",
       expect="the dim grey",
       script="runscenarios.py")

# The palette setting read by nothing.
mutate("Prompt/Prompt.lua",
       "\tlocal set = REASON_PALETTES[p and p.reasonPalette] or REASON_COLOR\n",
       "\tlocal set = REASON_COLOR\n",
       "the colour-blind palette never applied",
       expect="painted the same in both palettes",
       script="runscenarios.py")

# The list's bars left in the standard colours.
mutate("Prompt/List.lua",
       "\t\t\tlocal c = ReasonColor(row.reason)\n",
       "\t\t\tlocal palette = ns.db.profile.prompt.reasonPalette\n"
       "\t\t\tns.db.profile.prompt.reasonPalette = \"standard\"\n"
       "\t\t\tlocal c = ReasonColor(row.reason)\n"
       "\t\t\tns.db.profile.prompt.reasonPalette = palette\n",
       "queue bars ignore the palette",
       expect="the queue's bar for a group member",
       script="runscenarios.py")

# A palette nobody offers kept by the clamp.
mutate("Core.lua",
       '\toneOf(p, "reasonPalette", { standard = true, colourblind = true }, "standard")\n',
       "",
       "an unknown palette survives the clamp",
       expect="the clamp left the palette",
       script="runscenarios.py")

# No shrinking: a long line left to the client's ellipsis at full size.
mutate("Prompt/Text.lua",
       "\twhile size > least do\n",
       "\twhile false do\n",
       "long lines never fitted",
       expect="cut off by the client",
       script="runscenarios.py")

# Shrunk without a floor, to whatever fits.
mutate("Prompt/Text.lua",
       "\tlocal least = math.max(7, math.floor(base * 0.8 + 0.5))\n",
       "\tlocal least = 6\n",
       "a line shrunk past four fifths",
       expect="one that does not fit goes to",
       script="runscenarios.py")

# The chip's room kept by the lines when the chip is down.
mutate("Prompt/Text.lua",
       "\tlocal right = chipUp and fit.chipRoom or EDGE_ROOM\n",
       "\tlocal right = fit.chipRoom\n",
       "the chip's room never given back",
       expect="the reason line's room stayed",
       script="runscenarios.py")

# A line shrunk once and never put back to its size.
mutate("Prompt/Text.lua",
       "\tif fit.size[fs] ~= base then\n\t\tSafeFont(fs, fit.path, base, fit.flags)\n\t\tfit.size[fs] = base\n\tend\n",
       "",
       "a shrunk line never regrows",
       expect="stayed shrunk",
       script="runscenarios.py")

# The list's words after the name in the panel's dim grey in Minimal too: the
# row brightened under a code that overrides it.
mutate("Prompt/Text.lua",
       '\t\treason = "|cffbdbfd1" },\n',
       '\t\treason = "|cff707078" },\n',
       "minimal list words left dim",
       expect="bright after the name too",
       script="runscenarios.py")

# The coloured words held to body-text contrast: the list's grey and the
# deepest class colours all redrawn on the default panel.
mutate("Prompt/Text.lua",
       "local CODE_CONTRAST, TEXT_CONTRAST = 3, 4.5\n",
       "local CODE_CONTRAST, TEXT_CONTRAST = 4.6, 4.5\n",
       "default panel's near-line colours moved",
       expect="leaves the colours near its contrast line alone",
       script="runscenarios.py")

# The palette greyed out wherever the ring is off, though the list's bars,
# the glow and a press's wash still draw it.
mutate("Options.lua",
       "\t\t\t\t\treturn not p.accentByReason and not p.showQueue\n",
       "\t\t\t\t\treturn not p.accentByReason or (p.accentMode or \"icon\") == \"off\"\n",
       "reason palette locked with the ring off",
       expect="the Reason colours control is greyed out",
       script="runscenarios.py")

# The list's rows set straight onto the font string again, never fitted: a
# long name and a long spell name cut off by the client. (LegibleText is
# Text.lua's; with no base size FitLine returns at once, which is SetLine
# without the fitting.)
mutate("Prompt/List.lua",
       "\t\t\tSetLine(fs, text)\n",
       "\t\t\tlocal base = lib.fit.base[fs]\n"
       "\t\t\tlib.fit.base[fs] = nil\n"
       "\t\t\tSetLine(fs, text)\n"
       "\t\t\tlib.fit.base[fs] = base\n",
       "list rows not fitted",
       expect="a long row in the list is drawn smaller to fit",
       script="runscenarios.py")

# The rows given no size to fit from, so FitLine leaves them alone.
mutate("Prompt/Text.lua",
       "\t\tfit.base[fs], fit.size[fs] = subSize, subSize\n",
       "",
       "list rows with no base size",
       expect="a long row in the list is drawn smaller to fit",
       script="runscenarios.py")

# The options page's buttons left at AceConfigDialog's 170 pixels, whatever
# their label: "Put these back to de...".
mutate("Options.lua",
       '\t\t\t\tkind = "button"\n',
       '\t\t\t\tkind = false\n',
       "options buttons not fitted",
       expect="every options button and dropdown holds its words (enUS): button",
       script="runscenarios.py")

# ...and the dropdowns: "Above the action bars (d...".
mutate("Options.lua",
       '\t\t\t\tkind = "select"\n',
       '\t\t\t\tkind = false\n',
       "options dropdowns not fitted",
       expect="every options button and dropdown holds its words (enUS): dropdown",
       script="runscenarios.py")

# Measured without the room AceGUI keeps beside a button's label.
mutate("Options.lua",
       "local BUTTON_PAD = 30 + 6\n",
       "local BUTTON_PAD = 0\n",
       "options buttons fitted without the padding",
       expect="every options button and dropdown holds its words",
       script="runscenarios.py")

# ...or beside a dropdown's text.
mutate("Options.lua",
       "local SELECT_PAD = 36 + 6\n",
       "local SELECT_PAD = 0\n",
       "options dropdowns fitted without the padding",
       expect="every options button and dropdown holds its words",
       script="runscenarios.py")
