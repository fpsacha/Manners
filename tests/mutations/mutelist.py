# Mutations for the mute list Who to skip can leave out (Queue.lua, Mute and the
# walk; Ask.lua, Courtesy.lua, Cures.lua, Resurrect.lua; Options/Who.lua).
# Each is caught by the scenario in tests/scenarios/mutelist.lua that names it.

S = "runscenarios.py"

VISIT = "\t\tif opts.mute and not isOwed and not pointed and not owner\n"

mutate("Queue.lua", VISIT,
       "\t\tif false and opts.mute and not isOwed and not pointed and not owner\n",
       "mutelist: the walk never reads the list",
       expect="mutelist: a passer-by muted by name is left out with the switch on", script=S)

mutate("Queue.lua", VISIT,
       "\t\tif false and opts.mute and not isOwed and not pointed and not owner\n",
       "mutelist: the walk never reads the list (a request)",
       expect="mutelist: a request from somebody muted is not offered", script=S)

mutate("Queue.lua", VISIT,
       "\t\tif opts.mute and not pointed and not owner\n",
       "mutelist: a favour owed is left out too",
       expect="mutelist: somebody muted who buffed you is still offered the favour back", script=S)

mutate("Queue.lua", VISIT,
       "\t\tif opts.mute and not isOwed and not owner\n",
       "mutelist: the target is left out too",
       expect="mutelist: your target is still offered", script=S)

mutate("Queue.lua",
       "\t\tif not (db and db.filters.skipMuted == true) then return nil end\n",
       "\t\tif not db then return nil end\n",
       "mutelist: the switch is not read",
       expect="mutelist: off by default, and a muted passer-by is still offered", script=S)

mutate("Queue.lua",
       "m.enabled ~= true or type(m.names)",
       "type(m.names)",
       "mutelist: its own muting switch is not read",
       expect="mutelist: with its own muting switched off, nobody is skipped", script=S)

mutate("Queue.lua",
       "(type(allow) == \"table\" and allow[key]) or ",
       "",
       "mutelist: its never-mute list is not read",
       expect="mutelist: its never-mute list and a party pass let a player through", script=S)

mutate("Queue.lua",
       "(type(pass) == \"table\" and pass[key] ~= nil) or false",
       "false",
       "mutelist: a party pass is not read",
       expect="mutelist: its never-mute list and a party pass let a player through", script=S)

mutate("Queue.lua",
       "\t\tif type(open) == \"table\" and open[g] then return false end\n",
       "",
       "mutelist: a guild on its allow list is left out",
       expect="mutelist: a guild a word matches is left out, and a guild on its allow list is not", script=S)

mutate("Queue.lua",
       "g:find(w, 1, true)",
       "g == w",
       "mutelist: a guild word has to be the whole name",
       expect="mutelist: a guild a word matches is left out, and a guild on its allow list is not", script=S)

mutate("Queue.lua",
       "\t\tlocal g = guild:lower()\n",
       "\t\tlocal g = guild\n",
       "mutelist: the guild's case has to match",
       expect="mutelist: a guild a word matches is left out, and a guild on its allow list is not", script=S)

mutate("Queue.lua",
       "if realm then name = name .. \"-\" .. realm else settled = false end",
       "if realm then name = name else settled = false end",
       "mutelist: your own realm is not appended",
       expect="mutelist: names are keyed as the mute list keys them, a surname on Forever, a realm elsewhere", script=S)

mutate("Queue.lua",
       "(name:sub(dash + 1):gsub(\"[%s%-]\", \"\"))",
       "name:sub(dash + 1)",
       "mutelist: the realm keeps its spaces and dashes",
       expect="mutelist: names are keyed as the mute list keys them, a surname on Forever, a realm elsewhere", script=S)

mutate("Queue.lua",
       "got = { name:lower() }",
       "got = { name }",
       "mutelist: the key keeps its case",
       expect="mutelist: names are keyed as the mute list keys them, a surname on Forever, a realm elsewhere", script=S)

mutate("Queue.lua",
       "\t\t\tif first then got[2] = (first .. \"-\" .. last):lower() end\n",
       "",
       "mutelist: the old surname key is not tried",
       expect="mutelist: names are keyed as the mute list keys them, a surname on Forever, a realm elsewhere", script=S)

mutate("Queue.lua",
       "\t\t\tfn = _G.GetRealmName\n",
       "\t\t\tfn = nil\n",
       "mutelist: the plain realm name is not the fallback",
       expect="mutelist: your own realm is found from its plain name when there is no normalised one", script=S)

mutate("Options/Who.lua",
       "hidden = function() return type(rawget(_G, \"OlympusMuteDB\")) ~= \"table\" end,",
       "hidden = function() return type(rawget(_G, \"OlympusMuteDB\")) == \"nothing\" end,",
       "mutelist: the switch shows without the list",
       expect="mutelist: with no mute list the switch is hidden and nothing breaks", script=S)

mutate("Queue.lua",
       "\t\t\tor (mute and not (debt and LiveExpiry(debt) > now) and Mute.Listed(mute, name, nil, now, memo.guild))\n",
       "",
       "mutelist: a muted passer-by is offered from memory",
       expect="mutelist: a passer-by remembered is not offered from memory once muted", script=S)

mutate("Queue.lua",
       "\t\t\tor (mute and not (debt and LiveExpiry(debt) > now) and Mute.Listed(mute, name, nil, now, memo.guild))\n",
       "\t\t\tor (mute and not debt and Mute.Listed(mute, name, nil, now, memo.guild))\n",
       "mutelist: a lapsed favour exempts a muted passer-by from memory",
       expect="mutelist: a favour that has lapsed no longer lets somebody muted through from memory", script=S)

mutate("Ask.lua",
       "\tif ns.MuteListed(full, unit, now) then return nil end\n",
       "",
       "mutelist: a muted player is asked",
       expect="mutelist: nobody muted is asked for a buff", script=S)

mutate("Resurrect.lua",
       "\tif ns.MuteListed(name, unit, now)\n\t\tand not (plain(UnitIsUnit(unit, \"target\")) or plain(UnitIsUnit(unit, \"focus\"))) then return nil end\n",
       "",
       "mutelist: a muted player is offered a resurrection",
       expect="mutelist: nobody muted is offered a resurrection", script=S)

mutate("Courtesy.lua",
       "\t\telseif not st.pointed and ns.MuteListed(full, unit, now) then\n",
       "\t\telseif false and ns.MuteListed(full, unit, now) then\n",
       "mutelist: a courtesy for a muted player is offered",
       expect="mutelist: a courtesy asked for by somebody muted waits, and debug says why", script=S)

mutate("Cures.lua",
       "\t\t\tor ns.MuteListed(name, nil, now)\n",
       "",
       "mutelist: a cure is offered from memory to a muted player",
       expect="mutelist: a cure is not offered from memory to somebody muted", script=S)

mutate("Queue.lua",
       "\t\tif type(guild) ~= \"string\" or guild == \"\" then return false end\n",
       "\t\tif guild == \"\" then return false end\n",
       "mutelist: a guild that is not a string is used",
       expect="mutelist: a guild withheld as a secret is no error", script=S)

mutate("Queue.lua",
       "\t\t\t\tif not Through(m, key) then players = players + 1 end\n",
       "\t\t\t\tif not Through(m, key) then players = players + 2 end\n",
       "mutelist: debug counts every player twice",
       expect="mutelist: /manners debug says the switch, whether the list is there and how much it holds", script=S)
