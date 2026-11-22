# Mutations for what a battleground match hides (GitHub issue 29): your own
# buffs after a death (Core.lua's GoneWithDeath and its hooks in
# ReadOwnFamily, Queue.lua's SelfBuff, Clicks.lua's cast note) and a cast that
# landed covering a reading the game hides (Queue.lua's CoveredByCast, the
# settles' NoteCover and the late refusal's DropCover). Each is caught by the
# scenario in tests/scenarios/bg-hidden.lua that it names.

S = "runscenarios.py"

# --- your own, after a death ---

mutate("Core.lua",
       "\t\t\tif ns.GoneWithDeath(\"own:\" .. family.key, family.throughDeath) then return false end\n",
       "",
       "bg-hidden: a family a death took is not read as missing",
       expect="bg-hidden: a class's own family a death took is offered again", script=S)

mutate("Queue.lua",
       "\t\tif has == nil and ns.GoneWithDeath(buff.key, buff.throughDeath) then return false end\n",
       "",
       "bg-hidden: your group buff on yourself is not read as gone with a death",
       expect="bg-hidden: after a death your own buff is offered though the game hides your auras", script=S)

mutate("Core.lua",
       "\tns.NoteDeath(GetTime())\n",
       "",
       "bg-hidden: PLAYER_DEAD notes no death",
       expect="bg-hidden: after a death your own buff is offered though the game hides your auras", script=S)

mutate("Clicks.lua",
       "\t\tif buff and (NamesYou(to) or group) then ns.NoteCastSinceDeath(buff.key) end\n",
       "",
       "bg-hidden: a cast of yours since the death is not noted",
       expect="bg-hidden: a cast of your own since the death lets the hidden reading stand", script=S)

mutate("Core.lua",
       "return death.at ~= nil and not keeps and key ~= nil",
       "return death.at ~= nil and key ~= nil",
       "bg-hidden: a buff that outlasts death is guessed gone",
       expect="bg-hidden: a buff that outlasts death is not offered on a hidden reading", script=S)

mutate("Clicks.lua",
       "if buff and (NamesYou(to) or group) then",
       "if buff then",
       "bg-hidden: a cast on a team-mate is noted as your own",
       expect="bg-hidden: a cast on a team-mate leaves your own reading as it was", script=S)

# --- a team-mate you buffed ---

mutate("Queue.lua",
       "\tif has == nil and ns.CoveredByCast(opts.name, buff, opts.now, opts.guid) then return true, nil, true end\n",
       "",
       "bg-hidden: a cast that landed covers nothing",
       expect="bg-hidden: a team-mate you just buffed is not offered again while the game hides their buffs", script=S)

mutate("Queue.lua",
       "\tif has == nil and ns.CoveredByCast(opts.name, buff, opts.now, opts.guid) then return true, nil, true end\n",
       "\tif ns.CoveredByCast(opts.name, buff, opts.now, opts.guid) then return true, nil, true end\n",
       "bg-hidden: a cast covers a reading the client gave",
       expect="bg-hidden: a reading the client gives still decides", script=S)

mutate("Core.lua",
       "\t\tif ns.NoteSeenDead then ns.NoteSeenDead(guid, GetTime()) end\n",
       "",
       "bg-hidden: a team-mate seen dead keeps the cover",
       expect="bg-hidden: a team-mate seen dead since your cast is offered again", script=S)

mutate("Clicks.lua",
       "\tns.DropCover(settled.name, settled.buffKey, settled.at)\n",
       "",
       "bg-hidden: a late refusal leaves the cover",
       expect="bg-hidden: a late refusal takes the cover back", script=S)

mutate("Clicks.lua",
       "\t\tns.NoteCover(name, pending.buffKey, GetTime())\n",
       "",
       "bg-hidden: a group cast covers only the one it was aimed at",
       expect="bg-hidden: a group cast covers everybody it reached", script=S)
