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

mutate("Clicks.lua",
       "\t\t\tpcall(_G.RaidNotice_AddMessage, _G.RaidWarningFrame, line, { r = 1, g = 0.82, b = 0 })\n",
       "",
       "author-egg: no banner",
       expect="author-egg: it also shows across the screen, in gold in chat", script=S)

mutate("Clicks.lua",
       "\t\tif type(_G.PlaySound) == \"function\" then pcall(_G.PlaySound, 888) end\n",
       "",
       "author-egg: no fanfare",
       expect="author-egg: it also shows across the screen, in gold in chat", script=S)

mutate("Clicks.lua",
       "\t\tShowSeal(line)\n",
       "",
       "author-egg: no seal",
       expect="author-egg: the seal is shown under the line, then fades and goes", script=S)

mutate("Clicks.lua",
       "\t\telse\n\t\t\tself:Hide()\n\t\tend\n",
       "\t\tend\n",
       "author-egg: the seal never goes",
       expect="author-egg: the seal is shown under the line, then fades and goes", script=S)

mutate("Clicks.lua",
       "\t\t\tpcall(send.SendAddonMessage, PREFIX, WORD, \"WHISPER\", AUTHOR)\n",
       "",
       "author-egg: the author's Manners is never told",
       expect="author-egg: the author's Manners is told, once", script=S)

mutate("Clicks.lua",
       "\t\tif ns.plain(prefix) ~= PREFIX or ns.plain(text) ~= WORD then return end\n",
       "\t\tif ns.plain(prefix) ~= PREFIX then return end\n",
       "author-egg: any word from Manners is read",
       expect="author-egg: the author is told who it was, and nobody else is", script=S)

mutate("Clicks.lua",
       " ~= \"camelot\" or not ns.IsPlayerName(AUTHOR) then return end\n",
       " ~= \"camelot\" then return end\n",
       "author-egg: everybody is told",
       expect="author-egg: the author is told who it was, and nobody else is", script=S)

mutate("Clicks.lua",
       "\t\taddon:Print(\"|cffffd100\" .. L[\"%s buffed you with Manners.\"]:format(who) .. \"|r\")\n",
       "",
       "author-egg: the author is told nothing",
       expect="author-egg: the author is told who it was, and nobody else is", script=S)
