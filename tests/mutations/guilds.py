# Mutations for leaving guilds out and the guild line under a name (Queue.lua
# SkippedGuilds, GuildOf and the walk, Prompt/Paint.lua ReasonText, Core.lua,
# Options/Who.lua, Options/Look.lua). Each is caught by the scenario in
# tests/scenarios/guilds.lua that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif skipGuilds and (reason == \"group\" or reason == \"nearby\") and not pointed then\n",
       "\t\tif false and skipGuilds and (reason == \"group\" or reason == \"nearby\") and not pointed then\n",
       "guilds: the list is never read",
       expect="guilds: a passer-by of a listed guild is left out", script=S)

mutate("Queue.lua",
       "\t\tif skipGuilds and (reason == \"group\" or reason == \"nearby\") and not pointed then\n",
       "\t\tif skipGuilds and reason == \"nearby\" and not pointed then\n",
       "guilds: the group is not left out",
       expect="guilds: a member of your group in a listed guild is left out", script=S)

mutate("Queue.lua",
       "\t\tif skipGuilds and (reason == \"group\" or reason == \"nearby\") and not pointed then\n",
       "\t\tif skipGuilds and (reason == \"group\" or reason == \"nearby\") then\n",
       "guilds: the target is left out too",
       expect="guilds: your target and focus are still offered", script=S)

mutate("Queue.lua",
       "\t\tif skipGuilds and (reason == \"group\" or reason == \"nearby\") and not pointed then\n",
       "\t\tif skipGuilds and not pointed then\n",
       "guilds: a favour owed is left out too",
       expect="guilds: somebody who buffed you is still offered", script=S)

mutate("Queue.lua",
       "\t\t\tif guild and skipGuilds[guild:lower()] then\n",
       "\t\t\tif guild and skipGuilds[guild] then\n",
       "guilds: the case has to match",
       expect="guilds: a passer-by of a listed guild is left out, in any case", script=S)

mutate("Queue.lua",
       "\t\t\t\tname = name:match(\"^<(.*)>$\") or name\n",
       "",
       "guilds: the brackets are kept in the name",
       expect="guilds: lines, spaces and the game's <Name> all read", script=S)

mutate("Queue.lua",
       "\t\t\t\tlocal name = line:match(\"^%s*(.-)%s*$\")\n",
       "\t\t\t\tlocal name = line\n",
       "guilds: the spaces are kept in the name",
       expect="guilds: lines, spaces and the game's <Name> all read", script=S)

mutate("Queue.lua",
       "\t\tif type(name) ~= \"string\" or name == \"\" then name = nil end\n",
       "\t\tif type(name) ~= \"string\" then name = nil end\n",
       "guilds: an empty guild name is a guild",
       expect="guilds: a guild the client answers with nothing shows no brackets", script=S)

mutate("Queue.lua",
       "\t\tif showGuild then queue[#queue].guild = GuildOf(unit, full, now) end\n",
       "\t\tqueue[#queue].guild = GuildOf(unit, full, now)\n",
       "guilds: the guild is read with the switch off",
       expect="guilds: off by default, everybody is offered and no guild is read", script=S)

mutate("Queue.lua",
       "\t\tif showGuild then queue[#queue].guild = GuildOf(unit, full, now) end\n",
       "",
       "guilds: the entry never carries the guild",
       expect="guilds: the second line says the guild when asked", script=S)

mutate("Prompt/Paint.lua",
       "\tif p.showGuild == true and type(entry.guild) == \"string\" then\n",
       "\tif type(entry.guild) == \"string\" then\n",
       "guilds: the second line says the guild with the switch off",
       expect="guilds: the second line says the guild when asked", script=S)

mutate("Prompt/Paint.lua",
       "\t\tout = out == \"\" and (\"<\" .. entry.guild .. \">\") or (out .. \"  <\" .. entry.guild .. \">\")\n",
       "\t\tout = out .. \"  <\" .. entry.guild .. \">\"\n",
       "guilds: a blank reason keeps its gap",
       expect="guilds: a blank reason line is followed by no gap", script=S)

mutate("Core.lua",
       "\t\t\tshowGuild = false,\n",
       "\t\t\tshowGuild = true,\n",
       "guilds: the guild line is on by default",
       expect="guilds: off by default, everybody is offered and no guild is read", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 43.6,\n\t\t\t\tmultiline = 4,\n",
       "\t\t\t\torder = 43.6,\n",
       "guilds: the list is a one-line box",
       expect="guilds: Who to skip has the box and Look has the switch, both kept", script=S)
