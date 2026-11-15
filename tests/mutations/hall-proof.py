# Mutations for the hall of fame's proof (HallProof.lua: the certificate beside
# the ledger's Milestones tab; Ledger.lua's call to paint it and the tab
# Ledger.Show opens on; Options/Start.lua's button and its place in
# Options/Window/Layout.lua; Hall.lua's fold text; the issue form;
# tools/hall.py's record of the proof). Each is caught by the scenario in
# tests/scenarios/hall-proof.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "hall-proof: "
WHEN = P + "no certificate before the last milestone, on another tab or with milestones off"
WHAT = P + "the certificate names the character in class colour, the day, the count and the code the fold gives"
REALM = P + "a realm's character is named with its realm, and the longest code stays whole"
LINES = P + "the code's lines are of a length and put together are the code"
BUTTON = P + "Show my certificate opens the ledger on its Milestones tab"
FOLD = P + "the fold asks for a screenshot of the certificate, before and after"
FORM = P + "the form asks for the code and the screenshot, and the clerk keeps where the proof is"
PLACED = "every control has one place in the options window"

# When there is one.
mutate("HallProof.lua",
       "\tif not Hall.Shown() then return nil end\n\tlocal code = Hall.Code()\n",
       "\tlocal code = Hall.Code()\n",
       "hall-proof: a certificate's facts with milestones switched off",
       expect=WHEN, script=S)
mutate("HallProof.lua",
       "\tlocal facts = onTab and window and Hall.Certificate() or nil\n",
       "\tlocal facts = window and Hall.Certificate() or nil\n",
       "hall-proof: the certificate on every tab",
       expect=WHEN, script=S)
mutate("HallProof.lua",
       "\tif not facts then\n\t\tif panel then panel:Hide() end\n\t\treturn\n\tend\n",
       "\tif not facts then return end\n",
       "hall-proof: the certificate never goes away",
       expect=WHEN, script=S)
mutate("Ledger.lua",
       "\tif ns.Hall and ns.Hall.PaintCertificate then ns.Hall.PaintCertificate(window, page ~= nil) end\n",
       "\tif ns.Hall and ns.Hall.PaintCertificate then ns.Hall.PaintCertificate(window, true) end\n",
       "hall-proof: the ledger paints the certificate whatever the tab",
       expect=WHEN, script=S)
mutate("Ledger.lua",
       "\tif ns.Hall and ns.Hall.PaintCertificate then ns.Hall.PaintCertificate(window, page ~= nil) end\n",
       "",
       "hall-proof: the ledger never paints the certificate",
       expect=WHAT, script=S)
mutate("Options/Start.lua",
       "\t\t\t\t\treturn not (ns.Hall and ns.Hall.ShowCertificate and ns.Hall.Shown() and ns.Hall.Code() ~= nil)\n",
       "\t\t\t\t\treturn not (ns.Hall and ns.Hall.ShowCertificate and ns.Hall.Shown())\n",
       "hall-proof: a button to a certificate there is not yet",
       expect=WHEN, script=S)
mutate("Options/Start.lua",
       "\t\t\t\t\treturn not (ns.Hall and ns.Hall.ShowCertificate and ns.Hall.Shown() and ns.Hall.Code() ~= nil)\n",
       "\t\t\t\t\treturn not (ns.Hall and ns.Hall.ShowCertificate and ns.Hall.Code() ~= nil)\n",
       "hall-proof: the button shows with milestones switched off",
       expect=WHEN, script=S)

# What it says.
mutate("HallProof.lua",
       "\tpanel.name:SetText(Coloured(facts.name, facts.class))\n",
       "\tpanel.name:SetText(facts.name)\n",
       "hall-proof: the name in no class colour",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tpanel.detail:SetText((\"%s, %s\"):format(facts.className, facts.clientName))\n",
       "\tpanel.detail:SetText(facts.className)\n",
       "hall-proof: the certificate does not say which client",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tpanel.date:SetText(TEXT.DATE:format(facts.date))\n",
       "\tpanel.date:SetText(TEXT.DATE:format(facts.rows[#facts.rows].date))\n",
       "hall-proof: the certificate is dated the first milestone",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tpanel.count:SetText(TEXT.COUNT:format(facts.earned, facts.of))\n",
       "\tpanel.count:SetText(TEXT.COUNT:format(facts.earned, MAX_ROWS))\n",
       "hall-proof: the count is out of every milestone there is",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\t\t\trows[#rows + 1] = { name = row.def.name, date = Day(math.abs(row.earnedAt)) }\n",
       "\t\t\trows[#rows + 1] = { name = row.def.name, date = Day(row.earnedAt) }\n",
       "hall-proof: a milestone passed before they were kept has no date",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\t\tif row.earnedAt and #rows < MAX_ROWS then\n",
       "\t\tif row.earnedAt and #rows < 5 then\n",
       "hall-proof: the certificate lists a handful of the milestones",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\t\t\trow.date:SetText(fact.date)\n",
       "",
       "hall-proof: the milestones are listed without their dates",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tpanel.build:SetText(facts.build)\n",
       "",
       "hall-proof: the certificate does not say which Manners",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\t\tbuild = \"Manners \" .. tostring(ns.BUILD or \"\"),\n",
       "\t\tbuild = \"Manners\",\n",
       "hall-proof: the certificate names no version",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\t\t\tfs:SetText(lines[i])\n",
       "\t\t\tfs:SetText(lines[1])\n",
       "hall-proof: the certificate repeats the code's first line",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tlocal lines = Hall.CodeLines(facts.code, CODE_WIDTH)\n",
       "\tlocal lines = { facts.code }\n",
       "hall-proof: the code on one line the panel cuts",
       expect=WHAT, script=S)
mutate("HallProof.lua",
       "\tpanel:SetHeight(-y + PAD)\n",
       "",
       "hall-proof: a certificate of no height",
       expect=WHAT, script=S)

# Realms and the longest code.
mutate("HallProof.lua",
       "\tif who.realm ~= \"\" then name = name .. \"-\" .. who.realm:gsub(\"|\", \"\") end\n",
       "",
       "hall-proof: the certificate drops the realm",
       expect=REALM, script=S)
mutate("HallProof.lua",
       "\tif #lines > CODE_LINES then\n",
       "\tif false then\n",
       "hall-proof: the longest code runs out of lines",
       expect=REALM, script=S)

# The lines.
mutate("HallProof.lua",
       "\t\tlines[#lines + 1] = rest:sub(1, cut)\n\t\trest = rest:sub(cut + 1)\n",
       "\t\tlines[#lines + 1] = rest:sub(1, cut)\n\t\trest = rest:sub(cut + 2)\n",
       "hall-proof: a letter of the code lost at each line's end",
       expect=LINES, script=S)
mutate("HallProof.lua",
       "\t\tfor i = width, math.max(1, target - 8), -1 do\n",
       "\t\tfor i = width, 1, -1 do\n",
       "hall-proof: a line of the code cut at its first dash",
       expect=LINES, script=S)
mutate("HallProof.lua",
       "\twhile #rest > width do\n",
       "\twhile #rest > width + 8 do\n",
       "hall-proof: the code's last line runs past the edge",
       expect=LINES, script=S)

# The button.
mutate("Ledger.lua",
       "\tif type(tab) == \"string\" and FILTERS[tab] then SetFilter(tab) end\n",
       "",
       "hall-proof: the ledger opens on the tab it was left on",
       expect=BUTTON, script=S)
mutate("HallProof.lua",
       "\tLedger.Show(\"milestones\")\n",
       "\tLedger.Show()\n",
       "hall-proof: the button opens the ledger and not its Milestones tab",
       expect=BUTTON, script=S)
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"general.hallCertificate\",\n",
       "",
       "hall-proof: the button has no place in the window",
       expect=PLACED, script=S)

# The fold.
mutate("Hall.lua",
       " A screenshot of your certificate, which the favour ledger shows from then on, will be the proof.\"],\n",
       "\"],\n",
       "hall-proof: nothing says beforehand that a screenshot is the proof",
       expect=FOLD, script=S)
mutate("Hall.lua",
       "\\n1. Open your certificate with the button below.",
       "",
       "hall-proof: the invitation does not say to open the certificate",
       expect=FOLD, script=S)
mutate("Hall.lua",
       "nothing of value is asked for it.\"],\n",
       "a place is yours for the asking.\"],\n",
       "hall-proof: the invitation no longer says nothing is asked",
       expect=FOLD, script=S)

# The form and the clerk.
mutate(".github/ISSUE_TEMPLATE/hall-of-fame.yml",
       "      placeholder: Drag your screenshot here.\n    validations:\n      required: true\n",
       "      placeholder: Drag your screenshot here.\n    validations:\n      required: false\n",
       "hall-proof: the form takes a code with no screenshot",
       expect=FORM, script=S)
mutate("tools/hall.py",
       "            fields[\"proof\"] = (",
       "            proof = (",
       "hall-proof: the clerk forgets where the proof is",
       expect=FORM, script=S)
mutate("tools/hall.py",
       "            for line in checklist(fields, args.code):\n                print(\"  [ ] \" + line)\n",
       "",
       "hall-proof: check says nothing of the screenshot",
       expect=FORM, script=S)
