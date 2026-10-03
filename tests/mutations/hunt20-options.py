# Mutations for round 20's options fixes: a text setting holding a CR or
# another control character, written into a settings string, read back, and
# undone (Commands.lua), and a window place in the saved file that SetPoint
# cannot take (Options/Window/Window.lua). Each undoes a fix and is caught by
# the scenario in tests/scenarios/hunt20-options.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# A CR written as it is: a lone one, with nothing to turn it into a line
# break, is dropped with the other control characters, and two lines read
# back as one.
mutate("Commands.lua",
       "\t\ts = s:gsub(\"\\r\\n?\", \"\\n\"):gsub(\"[%z\\1-\\8\\11-\\31\\127]\", \"\")\n",
       "\t\ts = s:gsub(\"[%z\\1-\\8\\11-\\31\\127]\", \"\")\n",
       "hunt20-options: a CR in a setting is not a line break",
       expect="the phrase box reads back as", script=S)

# Control characters written as %XX, which DecodeText refuses: the player's
# own export cannot be imported.
mutate("Commands.lua",
       "\t\ts = s:gsub(\"\\r\\n?\", \"\\n\"):gsub(\"[%z\\1-\\8\\11-\\31\\127]\", \"\")\n",
       "\t\ts = s:gsub(\"\\r\\n?\", \"\\n\")\n",
       "hunt20-options: an export keeps a control character",
       expect="your own export cannot be imported back", script=S)

# A %0D refused again: the string 1.6.1 wrote from such a box will not read.
mutate("Commands.lua",
       "\t\ttext = text:gsub(\"\\r\\n?\", \"\\n\")\n",
       "",
       "hunt20-options: a string 1.6.1 wrote with a CR is refused",
       expect="hunt20-options: a string 1.6.1 wrote with a CR in the phrase box reads", script=S)

# The undo written out as a settings string and read back, as it was: what
# comes back is the box as the string carries it, not as the player had it.
mutate("Commands.lua",
       "\t\tlocal undo = { values = {} }\n"
       "\t\tfor _, field in ipairs(ShareFields()) do\n"
       "\t\t\tlocal holder = Holder(profile, field.path)\n"
       "\t\t\tif holder then undo.values[field.name] = CopyValue(holder[field.key]) end\n"
       "\t\tend\n",
       "\t\tlocal undo = Parse(ns.ExportSettings(), math.huge)\n",
       "hunt20-options: the undo kept as a settings string",
       expect="did not put the phrase box back", script=S)

# Any string taken as an anchor: SetPoint throws on FOO and the window never
# opens.
mutate("Options/Window/Window.lua",
       "\tif ANCHORS[s.point] and ANCHORS[relPoint] and Offset(s.x) and Offset(s.y) then\n",
       "\tif type(s.point) == \"string\" and type(relPoint) == \"string\" and Offset(s.x) and Offset(s.y) then\n",
       "hunt20-options: a saved anchor SetPoint cannot take",
       expect="the options window did not open", script=S)

# Any number taken as an offset, 1e300 and NaN included.
mutate("Options/Window/Window.lua",
       "\tif ANCHORS[s.point] and ANCHORS[relPoint] and Offset(s.x) and Offset(s.y) then\n",
       "\tif ANCHORS[s.point] and ANCHORS[relPoint] and type(s.x) == \"number\" and type(s.y) == \"number\" then\n",
       "hunt20-options: a saved offset no screen has",
       expect="the window was put at", script=S)

# A place SetPoint cannot take left in the saved file, met at every login.
mutate("Options/Window/Window.lua",
       "\t\ts.point, s.relPoint, s.x, s.y = nil, nil, nil, nil\n",
       "",
       "hunt20-options: a bad window place kept",
       expect="the place SetPoint cannot take is still saved", script=S)

# A place saved without its relative anchor, which the old code read as the
# same anchor, sent to the centre.
mutate("Options/Window/Window.lua",
       "\tif relPoint == nil then relPoint = s.point end\n",
       "",
       "hunt20-options: a place without its relative anchor lost",
       expect="the window is not where it was left", script=S)
