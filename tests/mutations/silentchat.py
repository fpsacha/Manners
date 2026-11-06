# Mutations for saying nothing at all in chat (Core.lua addon:Print and Reply,
# Commands.lua's HandleSlash wrapper, Options/Start.lua). Each is caught by the
# scenario in tests/scenarios/silentchat.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif db and db.silentChat == true and not ns.answering then return end\n",
       "",
       "silentchat: the switch holds nothing back",
       expect="silentchat: on, a line of Manners' own does not reach chat", script=S)

mutate("Core.lua",
       "\t\tif db and db.silentChat == true and not ns.answering then return end\n",
       "\t\tif db and db.silentChat == true then return end\n",
       "silentchat: a typed command is silenced too",
       expect="silentchat: on, a command typed in chat is still answered", script=S)

mutate("Core.lua",
       "\t\tif db and db.silentChat == true and not ns.answering then return end\n",
       "\t\tif db and (db.silentChat == true or db.verbose == false) and not ns.answering then return end\n",
       "silentchat: the chat switch silences everything",
       expect="silentchat: off by default, and then every line is printed, the chat switch off or on", script=S)

mutate("Core.lua",
       "\tfunction addon:Reply(...) return acePrint(self, ...) end\n",
       "\tfunction addon:Reply(...) return self:Print(...) end\n",
       "silentchat: a reply is silenced too",
       expect="silentchat: on, what pasting settings or loading a set says is still said", script=S)

mutate("Commands.lua",
       "\t\tns.answering = was\n",
       "",
       "silentchat: the answering flag is never put back",
       expect="silentchat: on, a command typed in chat is still answered", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tset = function(_, v) ns.db.profile.silentChat = v end,\n",
       "\t\t\t\tset = function() end,\n",
       "silentchat: the switch writes nothing",
       expect="silentchat: Start here has the switch, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"general.silentChat\",\n",
       "",
       "silentchat: the switch is not placed on the page",
       expect="silentChat", script=S)
