# The favour ledger's fixes from the third bug hunt, each put back wrong and
# required to be caught by the scenario in tests/scenarios/hunt3-ledger.lua
# written for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# A favour let go through the never-offer list keeps its reason.
mutate("Ledger.lua",
       "\twhy = WHY[why] and why or \"expired\"\n",
       "\twhy = \"expired\"\n",
       "hunt3 ledger: let go on purpose reads expired",
       expect="hunt3 ledger: a favour let go through the never-offer list says so", script=S)
mutate("Ledger.lua",
       "local WHY = { expired = true, useless = true, notkept = true, never = true }\n",
       "local WHY = { expired = true, useless = true, notkept = true }\n",
       "hunt3 ledger: never reason lost at a reload",
       expect="hunt3 ledger: a favour let go through the never-offer list says so", script=S)

# Today's count of buffs given does not stop where the list's share does.
mutate("Ledger.lua",
       "\tif s.today and s.today.day == today then out.given = math.max(out.given, s.today.given) end\n",
       "",
       "hunt3 ledger: today's gifts stop at 100",
       expect="hunt3 ledger: today's gifts are counted past a hundred", script=S)
mutate("Ledger.lua",
       "\ts.entries = kept\n\ts.today = nil\n",
       "\ts.entries = kept\n",
       "hunt3 ledger: Clear keeps today's count",
       expect="hunt3 ledger: today's gifts are counted past a hundred", script=S)

# Clear pressed between a return and its refusal.
mutate("Ledger.lua",
       "\ts.entries = kept\n\ts.today = nil\n",
       "\ts.entries = kept\n\ts.today = nil\n\twipe(recent)\n",
       "hunt3 ledger: Clear forgets the settles",
       expect="hunt3 ledger: Clear inside a refusal's window keeps the undo", script=S)
mutate("Ledger.lua",
       "\t\t\t\tif not Holds(s, e) then Append(s, e) end\n",
       "",
       "hunt3 ledger: a cleared favour is reopened nowhere",
       expect="hunt3 ledger: Clear inside a refusal's window keeps the undo", script=S)

# A refusal after the same person buffed you again.
mutate("Ledger.lua",
       "\t\t\tif open and open ~= e then\n",
       "\t\t\tif false then\n",
       "hunt3 ledger: refusal reopens a second owed row",
       expect="hunt3 ledger: a refusal after a second buff leaves one owed row", script=S)

# An owed row does not promise an offer the prompt cannot make.
mutate("Ledger.lua",
       "\tif quiet == \"owedoff\" then return TEXT.TIP_OWED_SOURCE_OFF end\n",
       "",
       "hunt3 ledger: owed row promises with source off",
       expect="hunt3 ledger: an owed row does not promise an offer", script=S)
mutate("Ledger.lua",
       "\tif snoozed and type(ends) == \"string\" then return snoozeLine:format(ends) end\n",
       "",
       "hunt3 ledger: owed row promises while snoozed",
       expect="hunt3 ledger: an owed row does not promise an offer", script=S)
mutate("Ledger.lua",
       "\tif okMounted and mounted == true then return mountLine end\n",
       "",
       "hunt3 ledger: owed row promises while mounted",
       expect="hunt3 ledger: an owed row does not promise an offer", script=S)

# Putting a giver on the never-offer list lets their favour go in the ledger,
# whichever way they were put on it.
mutate("Ledger.lua",
       "\t\t\t\t\tns.Guard(\"ledger LetGo\", Ledger.LetGo, name, \"never\")\n",
       "",
       "hunt3 ledger: never-offer list leaves the row owed",
       expect="hunt3 ledger: putting a giver on the never-offer list lets their favour go", script=S)

# A party-only favour held back by a snooze or a mount still waits on the party.
mutate("Ledger.lua",
       "\tif e.partyOnly then\n\t\tif ns.PARTY_IS_SUBGROUP then\n",
       "\tif false then\n\t\tif ns.PARTY_IS_SUBGROUP then\n",
       "hunt3 ledger: party-only row held back drops the party",
       expect="hunt3 ledger: a party-only favour held back still says it waits on the party", script=S)
