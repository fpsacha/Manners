# The favour ledger's fixes from the fifth bug hunt, each put back wrong and
# required to be caught by the scenario in tests/scenarios/hunt5-ledger.lua
# written for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# A Camelot name and surname in Cyrillic is longer than 48 bytes.
SURNAME = "hunt5 ledger: a long Cyrillic name and surname is filed"
mutate("Ledger.lua",
       "\tif name == \"\" or #name > 97 then return nil end\n",
       "\tif name == \"\" or #name > 48 then return nil end\n",
       "hunt5 ledger: name cap back at 48 bytes",
       expect=SURNAME, script=S)
mutate("Ledger.lua",
       "\tif name == \"\" or #name > 97 then return nil end\n",
       "\tif name == \"\" or #name > 98 then return nil end\n",
       "hunt5 ledger: name cap a byte too wide",
       expect=SURNAME, script=S)

# Midnight from the date, not counted back from the hour.
DST = "hunt5 ledger: today starts at midnight on the day the clocks change"
mutate("Ledger.lua",
       "\t\t\tand back.day == t.day and back.month == t.month then\n\t\t\treturn midnight\n",
       "\t\t\tand back.day == t.day and back.month == t.month then\n",
       "hunt5 ledger: midnight counted back from the hour",
       expect=DST, script=S)

# A font that will not load falls back to the game's own.
FONT = "hunt5 ledger: a font that will not load does not break the window"
mutate("Ledger.lua",
       "\tSafeFont(fs, Font(), size, \"\")\n",
       "\tfs:SetFont(Font(), size, \"\")\n",
       "hunt5 ledger: ledger font set unchecked",
       expect=FONT, script=S)
mutate("Ledger.lua",
       "\tif not fs:SetFont(path, size, flags) or (fs.GetFont and not fs:GetFont()) then\n",
       "\tif not fs:SetFont(path, size, flags) then\n",
       "hunt5 ledger: a font set that claims success is trusted",
       expect=FONT, script=S)

# A buff somebody asked for is listed, not counted as unprompted.
ASKED = "hunt5 ledger: a buff somebody asked for is not unprompted"
mutate("Ledger.lua",
       "\t\tif not asked then today.given = today.given + 1 end\n",
       "\t\ttoday.given = today.given + 1\n",
       "hunt5 ledger: asked-for buff counted for today",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "\t\t\telseif not e.asked then\n\t\t\t\tout.given = out.given + 1\n",
       "\t\t\telse\n\t\t\t\tout.given = out.given + 1\n",
       "hunt5 ledger: asked-for rows counted in the summary",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "to = to, asked = asked or nil,\n",
       "to = to,\n",
       "hunt5 ledger: asked-for row not marked",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "\t\t\tasked = e.asked == true or nil }\n",
       "\t\t\t}\n",
       "hunt5 ledger: asked mark lost at a reload",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "\t\t\tasked = e.asked == true or nil }\n",
       "\t\t\tasked = e.asked }\n",
       "hunt5 ledger: a damaged asked mark kept",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "\t\tif not e.asked then Untoday(s, \"given\", e.at) end\n",
       "\t\tUntoday(s, \"given\", e.at)\n",
       "hunt5 ledger: refused asked-for buff comes off today's gifts",
       expect=ASKED, script=S)
mutate("Ledger.lua",
       "\t\tif e.asked then GameTooltip:AddLine(TEXT.TIP_GAVE_ASKED, 0.7, 0.7, 0.7, true) end\n",
       "",
       "hunt5 ledger: asked-for row's tooltip silent",
       expect=ASKED, script=S)

# Today's favours are counted apart from the list.
BUSY = "hunt5 ledger: today's favours are counted past the list's end"
UNDO = "hunt5 ledger: a refused return comes off today's counts"
mutate("Ledger.lua",
       "\t\tfor _, key in ipairs(TODAY) do out[key] = math.max(out[key], s.today[key] or 0) end\n",
       "",
       "hunt5 ledger: today's favours counted off the list",
       expect=BUSY, script=S)
mutate("Ledger.lua",
       "\t\ttoday[key] = today[key] + 1\n",
       "",
       "hunt5 ledger: a favour received is not counted for today",
       expect=BUSY, script=S)
mutate("Ledger.lua",
       "\t\tlocal key = useless and \"useless\" or \"received\"\n",
       "\t\tlocal key = \"received\"\n",
       "hunt5 ledger: a useless favour counted as received today",
       expect=BUSY, script=S)
mutate("Ledger.lua",
       "\t\tif StartOfToday(e.at) == today.day then today.returned = today.returned + 1 end\n",
       "",
       "hunt5 ledger: a return is not counted for today",
       expect=BUSY, script=S)
mutate("Ledger.lua",
       "\t\t\tif StartOfToday(at) == today.day then today.received = today.received + 1 end\n",
       "",
       "hunt5 ledger: a favour made up at its return is not counted for today",
       expect=UNDO, script=S)
mutate("Ledger.lua",
       "\t\tUntoday(s, \"returned\", e.at)\n",
       "",
       "hunt5 ledger: a refused return stays in today's count",
       expect=UNDO, script=S)
mutate("Ledger.lua",
       "\t\t\tUntoday(s, \"received\", e.at)\n",
       "",
       "hunt5 ledger: a made-up favour refused stays in today's count",
       expect=UNDO, script=S)
mutate("Ledger.lua",
       "\t\t\t\tUntoday(s, \"received\", math.max(open.at, e.at))\n",
       "",
       "hunt5 ledger: a folded favour is counted twice today",
       expect=UNDO, script=S)
mutate("Ledger.lua",
       "\t\t\ts.today[key] = Whole(today[key]) and today[key] or 0\n",
       "\t\t\ts.today[key] = today[key]\n",
       "hunt5 ledger: a damaged count of today's favours trusted",
       expect=BUSY, script=S)
mutate("Ledger.lua",
       "\ts.entries = kept\n\ts.today = nil\n",
       "\ts.entries = kept\n",
       "hunt5 ledger: Clear keeps today's favour counts",
       expect=UNDO, script=S)
