# Mutations for the line said to somebody who buffs the author's character
# (Clicks.lua, ns.NoteBuffedAuthor). Each is caught by the scenario in
# tests/scenarios/author-egg.lua that names it.

S = "runscenarios.py"

mutate("Clicks.lua",
       "\tif not unheard then ns.NoteBuffedAuthor(pending.name) end\n",
       "",
       "author-egg: the settle never tells",
       expect="author-egg: a press that lands on the author says so once", script=S)

mutate("Clicks.lua",
       "if told or name ~= AUTHOR or",
       "if name ~= AUTHOR or",
       "author-egg: said every time",
       expect="author-egg: a press that lands on the author says so once", script=S)

mutate("Clicks.lua",
       "if told or name ~= AUTHOR or",
       "if told or",
       "author-egg: anybody counts",
       expect="author-egg: nobody else counts", script=S)

mutate("Clicks.lua",
       " or ns.Flavour.flavour ~= \"camelot\" or ns.IsPlayerName(name) then return end",
       " or ns.IsPlayerName(name) then return end",
       "author-egg: on every client",
       expect="author-egg: only on WoW Forever", script=S)

mutate("Clicks.lua",
       " or ns.Flavour.flavour ~= \"camelot\" or ns.IsPlayerName(name) then return end",
       " or ns.Flavour.flavour ~= \"camelot\" then return end",
       "author-egg: told to the author",
       expect="author-egg: never for the author", script=S)

mutate("Clicks.lua",
       "\t\t\tscreen:AddMessage(line, 1, 0.82, 0)\n",
       "",
       "author-egg: nothing across the screen",
       expect="author-egg: it also shows across the screen, in gold in chat", script=S)

mutate("Clicks.lua",
       "\t\taddon:Print(\"|cffffd100\" .. line .. \"|r\")\n",
       "\t\taddon:Print(line)\n",
       "author-egg: the chat line is plain",
       expect="author-egg: it also shows across the screen, in gold in chat", script=S)

mutate("Clicks.lua",
       "\t\t\tpcall(_G.DoEmote, \"BOW\")\n",
       "",
       "author-egg: no bow",
       expect="author-egg: it also shows across the screen, in gold in chat", script=S)
