# Mutations for the pasted never-offer list and the commas in the guild box
# (Queue.lua NeverOfferList, SkippedGuilds, TidyGuildList; Options/Who.lua;
# Options/Window/Layout.lua). Each is caught by the scenario in
# tests/scenarios/skiplist.lua that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\t\tfor line in text:gmatch(\"[^\\r\\n,]+\") do\n",
       "\t\t\tfor line in text:gmatch(\"[^\\r\\n]+\") do\n",
       "skiplist: the guild list is not split at commas",
       expect="skiplist: guilds with commas between are each left out", script=S)

mutate("Queue.lua",
       "\t\t\tif name ~= \"\" and not seen[key] then\n",
       "\t\t\tif name ~= \"\" then\n",
       "skiplist: the guild box keeps repeats",
       expect="skiplist: the guild box keeps one guild a line, blanks and repeats dropped", script=S)

mutate("Options/Who.lua",
       "set = function(info, value) fSet(info, ns.TidyGuildList(value)) end,",
       "set = fSet,",
       "skiplist: the guild box does not tidy what it keeps",
       expect="skiplist: the guild box keeps one guild a line, blanks and repeats dropped", script=S)

mutate("Queue.lua",
       "\tfor piece in text:gmatch(\"[^\\r\\n,]+\") do\n\t\tlocal listed, was",
       "\tfor piece in text:gmatch(\"[^\\r\\n]+\") do\n\t\tlocal listed, was",
       "skiplist: the pasted names are not split at commas",
       expect="skiplist: a pasted list puts every name on the never-offer list", script=S)

mutate("Queue.lua",
       "\t\tlocal listed, was = ns.NeverOffer(piece, true)\n",
       "\t\tlocal listed, was = ns.PutOnNeverList(piece, true)\n",
       "skiplist: a pasted name lets the favour owed go",
       expect="skiplist: a pasted name who buffed you is still offered the favour back", script=S)

mutate("Queue.lua",
       "\t\t\tif was then already = already + 1 else added = added + 1 end\n",
       "\t\t\tadded = added + 1\n",
       "skiplist: a name already listed counts as added",
       expect="skiplist: duplicates and names already listed are passed over", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 52.5,\n\t\t\t\tmultiline = 4,\n",
       "\t\t\t\torder = 52.5,\n",
       "skiplist: the paste box is a one-line box",
       expect="skiplist: the paste box sits under Never offer and is empty after", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.neverPaste\",\n",
       "",
       "skiplist: the paste box has no place in the window",
       expect="skiplist: the paste box sits under Never offer and is empty after", script=S)
