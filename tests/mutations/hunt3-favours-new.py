# Mutations for the third hunt's pass over the day's new favours. Each is
# caught by the scenario in tests/scenarios/hunt3-favours-new.lua that names it.

S = "runscenarios.py"

# A user the roster stopped naming is forgotten outright: back on it, the
# hello to them asks for nothing.
BACK = "hunt3-favours-new: a user the roster dropped is asked for a hello once back on it"
mutate("Share.lua",
       "\t\t\tusers[name] = nil\n\t\t\tlost[name] = true\n",
       "\t\t\tusers[name] = nil\n",
       "hunt3-favours-new: a user dropped by the roster is not asked again",
       expect=BACK, script=S)

# The asking is never taken back: every hello after it asks for an answer.
mutate("Share.lua",
       "\t\tself.greeted, self.newcomer, self.reply, self.said = true, false, false, sig\n\t\tself.ask = false\n",
       "\t\tself.greeted, self.newcomer, self.reply, self.said = true, false, false, sig\n",
       "hunt3-favours-new: every hello after one that asked asks too",
       expect=BACK, script=S)

# A hello refused for the roster leaves nothing behind.
mutate("Share.lua",
       "\tif not unit then Share.ask = true end\n",
       "",
       "hunt3-favours-new: a hello lost to the roster is not asked for again",
       expect="hunt3-favours-new: a hello heard before the roster names its sender is asked for again", script=S)

# The shout the walk left to another user reads as one nobody was in reach of.
SHOUT = "hunt3-favours-new: a shout left to another user is not offered on yourself"
mutate("Queue.lua",
       "\tif ns.ShareShoutHeld and ns.ShareShoutHeld(queue) then ns.shoutUnreached = nil end\n",
       "",
       "hunt3-favours-new: a shout left to another user is offered on yourself",
       expect=SHOUT, script=S)
mutate("Share.lua",
       "\tif buff.selfCast then shoutHeld = true end\n",
       "",
       "hunt3-favours-new: a shout held for another user is not remembered",
       expect=SHOUT, script=S)

# The hello says the raid night's groups before the gates open too.
mutate("Share.lua",
       "\tif ns.Battle and ns.Battle.State() == \"prep\" then skip = nil end\n",
       "",
       "hunt3-favours-new: the hello keeps the raid night's groups before the gates open",
       expect="hunt3-favours-new: before the gates open the hello says every raid group", script=S)

# A please written inside a word is no small word beside a nickname.
mutate("Requests.lua",
       "\t\t\t\t\tor Among(ASK.aside, word) or PleaseWord(word)) then\n",
       "\t\t\t\t\tor Among(ASK.aside, word)) then\n",
       "hunt3-favours-new: a Korean please beside a nickname drops it",
       expect="hunt3-favours-new: a Korean or Chinese please beside a one-word name is read", script=S)

# Any word that begins with the Chinese please counts as one.
mutate("Requests.lua",
       "\t\t\tif word == inside or (inside:byte() >= 234 and word:sub(1, #inside) == inside) then return true end\n",
       "\t\t\tif word:sub(1, #inside) == inside then return true end\n",
       "hunt3-favours-new: a Chinese sentence that opens with a please is a small word",
       expect="hunt3-favours-new: a Korean or Chinese please beside a one-word name is read", script=S)

mutate("Requests.lua",
       "\t\t\t\"again\", \"too\", \"also\", \"谢谢\", \"謝謝\" }),\n",
       "\t\t\t\"again\", \"too\", \"also\" }),\n",
       "hunt3-favours-new: a Chinese thanks beside a nickname drops it",
       expect="hunt3-favours-new: a Chinese thanks beside a one-word name is read", script=S)

# "drink" is a name for water again.
mutate("Courtesy.lua",
       "\"water\", \"waters\", \"mage water\", \"wasser\"",
       "\"water\", \"waters\", \"mage water\", \"drink\", \"drinks\", \"wasser\"",
       "hunt3-favours-new: somebody who says they drink is offered water",
       expect="hunt3-favours-new: somebody who says they drink asks for no water", script=S)

# One member's resurrection keeps the plain words of a group member.
mutate("Prompt/Button.lua",
       "\tif entry.resNames or entry.res then why = ns.Resurrect.Reason(entry) end\n",
       "\tif entry.resNames then why = ns.Resurrect.Reason(entry) end\n",
       "hunt3-favours-new: one member's resurrection says In your group",
       expect="hunt3-favours-new: one member's resurrection says dead in its tooltip", script=S)
