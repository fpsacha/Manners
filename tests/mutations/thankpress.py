# Mutations for Ask me before thanking (prompt.thankAsk: ThankPress.lua, and
# its hooks in Favours.lua, Core.lua, Prompt/Press.lua, Prompt/Macro.lua,
# Prompt/Paint.lua, Prompt/Button.lua, Options/Launcher.lua, Options/Say.lua,
# the layout, Commands.lua and Options/Diagnostics.lua). Each is caught by the
# scenario in tests/scenarios/thankpress.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------ the setting
mutate("Core.lua",
       "\t\t\tthankAsk = false,\n",
       "\t\t\tthankAsk = true,\n",
       "thankpress: on by default",
       expect="thankpress: off by default, the thanks go by themselves", script=S)

mutate("Favours.lua",
       "\t\tif ask and ask.thankAsk == true and ns.ThankPark then\n",
       "\t\tif false then\n",
       "thankpress: the switch is never read",
       expect="thankpress: on, nothing goes by itself and the prompt offers the thank", script=S)

mutate("Favours.lua",
       "\t\tif db.prompt.thankAsk == true and ns.ThankPark then\n",
       "\t\tif false then\n",
       "thankpress: a landing nobody named is thanked by itself",
       expect="thankpress: unseen, parked with a target held, and a press asks to clear it", script=S)

# ------------------------------------------------ the entry
mutate("Core.lua",
       "\tif buff.thankInfo then return buff.thankInfo end\n",
       "",
       "thankpress: the buff they gave has no name",
       expect="thankpress: on, nothing goes by itself and the prompt offers the thank", script=S)

mutate("Prompt/Paint.lua",
       "\tif entry.thank then return ns.ThankPress.Reason(entry) end\n",
       "",
       "thankpress: the prompt's second line a passer-by's",
       expect="thankpress: on, nothing goes by itself and the prompt offers the thank", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.thank then return ns.ThankArm(R, S, entry) end\n",
       "",
       "thankpress: armed as a cast",
       expect="thankpress: on, nothing goes by itself and the prompt offers the thank", script=S)

mutate("Core.lua",
       "\tif ns.ThankPending and ns.ThankPending() then return true end\n",
       "",
       "thankpress: no prompt for a rogue with a thank waiting",
       expect="thankpress: a rogue has a prompt while a thank waits, and none after", script=S)

# ------------------------------------------------ the order
mutate("ThankPress.lua",
       "TP.PRIORITY = 2.5\n",
       "TP.PRIORITY = 8\n",
       "thankpress: behind every passer-by",
       expect="thankpress: a buff your group needs comes first, then the thank, then a passer-by", script=S)

mutate("ThankPress.lua",
       "\t\tif entry.name and not entry.ask then taken[entry.name] = true end\n",
       "",
       "thankpress: thanked beside a buff they are owed",
       expect="thankpress: somebody you owe a buff is thanked once it is done", script=S)

mutate("ThankPress.lua",
       "\t\t\tfor _, member in ipairs(group.members) do taken[member] = true end\n",
       "",
       "thankpress: thanked beside a group cast that covers them",
       expect="thankpress: a member a group cast covers is thanked once it is done", script=S)

mutate("ThankPress.lua",
       "\t\t\t\tif queue[i].ask and queue[i].name == entry.name then table.remove(queue, i) end\n",
       "",
       "thankpress: an ask of the same person kept beside the thank",
       expect="thankpress: an ask of the same person gives way to the thank", script=S)

# ------------------------------------------------ the press
mutate("Prompt/Press.lua",
       "\tif S.current and S.current.thank then return ns.ThankPress.Pressed(S) end\n",
       "",
       "thankpress: a press files nothing",
       expect="thankpress: a press sends what would have gone by itself", script=S)

mutate("ThankPress.lua",
       "\tlocal why = ns.ThankNow.Press(item.seen, emote, whisper, item.unseen)\n",
       "\tlocal why = nil\n",
       "thankpress: a press sends nothing",
       expect="thankpress: a press sends what would have gone by itself", script=S)

mutate("Favours.lua",
       "\t\t\tlocal why = Blocked(seen, now, true)\n"
       "\t\t\tif why then return Skip(name, now, why) end\n"
       "\t\t\treturn ns.ThankPark",
       "\t\t\tlocal why = Blocked(seen, now)\n"
       "\t\t\tif why then return Skip(name, now, why) end\n"
       "\t\t\treturn ns.ThankPark",
       "thankpress: the gap holds back a thank that waits for a press",
       expect="thankpress: a press sends what would have gone by itself", script=S)

mutate("Favours.lua",
       "\t\t\tlocal why, unit = Blocked(probe, now, true)\n",
       "\t\t\tlocal why, unit = Blocked(probe, now)\n",
       "thankpress: the gap holds back a second press",
       expect="thankpress: two givers, two presses, two thanks", script=S)

mutate("Favours.lua",
       "\t\t\t\tprobe.unit = ns.UnitFor(seen.name, seen.unit)\n",
       "",
       "thankpress: the landing's token trusted at the press",
       expect="thankpress: the giver's token is looked for again at the press", script=S)

mutate("Prompt/Press.lua",
       "\tif not ready and not InCombatLockdown() and S.current and S.current.thank then\n",
       "\tif false then\n",
       "thankpress: a thank held back by the cooldown",
       expect="thankpress: the prompt's key thanks during the global cooldown", script=S)

mutate("Prompt/Press.lua",
       "\tif top and top.thank then\n"
       "\t\tPrompt:ApplyTarget(top, true)\n",
       "\tif false then\n"
       "\t\tPrompt:ApplyTarget(top, true)\n",
       "thankpress: a thank's press judged as a cast's line",
       expect="thankpress: unseen, no line left out is said at the press", script=S)

mutate("Prompt/Press.lua",
       "\tif S.current and top and top.name == S.current.name and (top.thank ~= nil) ~= (S.current.thank ~= nil) then\n",
       "\tif false then\n",
       "thankpress: a press on a thank casts a buff shown since",
       expect="thankpress: a press follows the panel's kind, a thank is never a cast", script=S)

# ------------------------------------------------ lapsing
mutate("ThankPress.lua",
       "TP.EXPIRE = 20\n",
       "TP.EXPIRE = 200\n",
       "thankpress: never lapses on the prompt",
       expect="thankpress: twenty seconds on the prompt and it lapses, nothing sent", script=S)

mutate("ThankPress.lua",
       "\t\tlocal _, _, any = ItemChannels(item, p)\n",
       "\t\tlocal _, _, any = ItemChannels(item, p)\n"
       "\t\titem.shownAt = item.shownAt or now\n",
       "thankpress: the clock starts on a thank nobody saw",
       expect="thankpress: twenty seconds on the prompt and it lapses, nothing sent", script=S)

mutate("ThankPress.lua",
       "\tns.MarkAttempted(NameOf(item), \"thank:\" .. item.id, 30)\n",
       "",
       "thankpress: a thank gone from the queue kept on the panel",
       expect="thankpress: two givers, two presses, two thanks", script=S)

mutate("ThankPress.lua",
       "TP.DEADLINE = 60\n",
       "TP.DEADLINE = 600\n",
       "thankpress: a thank nobody saw never lapses",
       expect="thankpress: a minute after the landing it lapses, shown or not", script=S)

# ------------------------------------------------ a fight
mutate("ThankPress.lua",
       "\tif prompt and prompt.armedForFight == true then return true end\n",
       "",
       "thankpress: the pull's own repaint offers a thank",
       expect="thankpress: a fight drops it and nothing is sent", script=S)

mutate("ThankPress.lua",
       "\t\tns.Guard(\"thank press reset\", DropAll, false)\n",
       "",
       "thankpress: a thank outlives the fight",
       expect="thankpress: a fight drops it and nothing is sent", script=S)

# ------------------------------------------------ several givers, letting go
mutate("ThankPress.lua",
       "found.seen, found.emote, found.whisper, found.at, found.entry = seen, emote == true, whisper == true, now, nil\n",
       "found.seen, found.emote, found.whisper, found.at = seen, emote == true, whisper == true, now\n",
       "thankpress: a newer landing keeps the older buff's name",
       expect="thankpress: a second buff from the same giver is the same thank, for the newer buff", script=S)

mutate("ThankPress.lua",
       "\tif at and now - at < (seen.inGroup and PER_MEMBER or PER_PERSON) then return end\n",
       "",
       "thankpress: a thank let go comes straight back",
       expect="thankpress: let go or lapsed, the same giver's next buffs are not offered", script=S)

mutate("Prompt/Press.lua",
       "\t\tif S.current and S.current.thank and (S.isRow or Prompt:PanelName() == S.current.name) then\n",
       "\t\tif false then\n",
       "thankpress: a right-click on a thank skips and lists the giver",
       expect="thankpress: a right-click lets it go, nothing sent and nobody blocked", script=S)

mutate("ThankPress.lua",
       "\t\telseif not any then\n"
       "\t\t\tDrop(i, false)\n",
       "\t\telseif false then\n"
       "\t\t\tDrop(i, false)\n",
       "thankpress: a thank with nothing to send stays",
       expect="thankpress: a thank with nothing left to send is dropped", script=S)

# ------------------------------------------------ nobody named
mutate("Favours.lua",
       "\t\t\tlocal why = UnseenBlocked(seen, now, true, true)\n",
       "\t\t\tlocal why = UnseenBlocked(seen, now, true)\n",
       "thankpress: a landing nobody named not parked with a target held",
       expect="thankpress: unseen, parked with a target held, and a press asks to clear it", script=S)

mutate("ThankPress.lua",
       "\t\ttable.insert(pending, math.min(i, #pending + 1), item)\n",
       "",
       "thankpress: a press with a target drops the thank",
       expect="thankpress: unseen, parked with a target held, and a press asks to clear it", script=S)

mutate("ThankPress.lua",
       "\t\t\tif item.seen.byName and same then return end\n",
       "",
       "thankpress: one landing read twice is two thanks",
       expect="thankpress: classic: a whisper by name and the scan's reading of one landing are one thank", script=S)

# ------------------------------------------------ what is said of it
mutate("Prompt/Button.lua",
       "\t\tif S.current.thank then\n"
       "\t\t\tGameTooltip:AddLine(L[\"Click to thank them.\"]",
       "\t\tif false then\n"
       "\t\t\tGameTooltip:AddLine(L[\"Click to thank them.\"]",
       "thankpress: the tooltip says a click casts",
       expect="thankpress: the tooltip and the launcher say what a press does", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.thank then return ns.ThankPress.Summary(entry) end\n",
       "",
       "thankpress: the tooltip describes a cast",
       expect="thankpress: the tooltip and the launcher say what a press does", script=S)

mutate("Options/Launcher.lua",
       "\t\tif entry.thank then\n"
       "\t\t\tperson:CreateButton(L[\"Let it go\"]",
       "\t\tif false then\n"
       "\t\t\tperson:CreateButton(L[\"Let it go\"]",
       "thankpress: the launcher offers to skip or list the giver",
       expect="thankpress: the tooltip and the launcher say what a press does", script=S)

mutate("Commands.lua",
       "\tfor _, line in ipairs(ns.ThankPressLines and ns.ThankPressLines(now) or {}) do self:Print(\"    \" .. line) end\n",
       "",
       "thankpress: /manners debug says nothing of the thanks waiting",
       expect="thankpress: /manners debug says the switch is on and who waits", script=S)

mutate("Options/Diagnostics.lua",
       "\tlines[#lines + 1] = (\"thankAsk=%s\"):format(tostring(db.prompt.thankAsk))\n",
       "",
       "thankpress: the check-up leaves the switch out",
       expect="thankpress: /manners debug says the switch is on and who waits", script=S)

mutate("Commands.lua",
       "\tif db.prompt.thankDelay == true and db.prompt.thankAsk ~= true then\n",
       "\tif db.prompt.thankDelay == true then\n",
       "thankpress: /manners debug says a pause the thanks do not wait",
       expect="thankpress: the pause before thanking is left out", script=S)

# ------------------------------------------------ the options
mutate("Options/Say.lua",
       "THANKS_ONLY.thankAsk = true\n",
       "",
       "thankpress: hidden from a class with nothing to give",
       expect="thankpress: What I say has the switch, for a rogue too", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tdisabled = function() return not (P().thankEmote or P().thankWhisper) or P().thankAsk == true end,\n",
       "\t\t\t\tdisabled = function() return not (P().thankEmote or P().thankWhisper) end,\n",
       "thankpress: the pause live while the thanks wait for a press",
       expect="thankpress: What I say has the switch, for a rogue too", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\tif p and p.thankAsk == true then return L[\"Off while %s is on.\"]:format(NameOf(\"click.thankAsk\")) end\n",
       "",
       "thankpress: the pause greyed with no word why",
       expect="thankpress: What I say has the switch, for a rogue too", script=S)

mutate("Commands.lua",
       "\t\t[\"prompt.thankAsk\"] = true,\n",
       "",
       "thankpress: a paste sends the thanks by themselves again",
       expect="thankpress: a pasted string can hold the thanks, never send them by themselves", script=S)

# ------------------------------------------------ the review of 1ce7e86
mutate("ThankPress.lua",
       "\t\t\tDrop(i, item.shownAt ~= nil)\n",
       "\t\t\tDrop(i, true)\n",
       "thankpress: a lapse nobody saw counts as let go",
       expect="thankpress: a thank the prompt never showed holds back none of their next ones", script=S)

mutate("ThankPress.lua",
       "\t\twhile #pending > TP.MAX do Drop(1, pending[1].shownAt ~= nil) end\n",
       "\t\twhile #pending > TP.MAX do Drop(1, true) end\n",
       "thankpress: one pushed out unseen counts as let go",
       expect="thankpress: the sixth giver pushes out one never shown, who may be offered again", script=S)

mutate("Favours.lua",
       "\t\t\treturn Send(probe, emote, whisper, unit, now)\n",
       "\t\t\tSend(probe, emote, whisper, unit, now)\n",
       "thankpress: a press the game refused reads as thanked",
       expect="thankpress: a press the game refuses says so", script=S)

mutate("ThankPress.lua",
       "\tif thankNow and thankNow.Held(pending[1].seen) then\n\t\tUnshown()\n\t\treturn queue, verdicts\n\tend\n",
       "",
       "thankpress: a thank offered while stealthed",
       expect="thankpress: stealthed, the thank is kept off the prompt until you show yourself", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\t\tif name ~= nobody then Alias(name) end\n",
       "\t\t\t\tAlias(name)\n",
       "thankpress: the check-up aliases whoever buffed you",
       expect="thankpress: the full check-up names nobody for an unseen thank", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\tlocal who = e.thankUnseen and \"(unseen)\" or Alias(e.name)\n",
       "\t\t\tlocal who = Alias(e.name)\n",
       "thankpress: the check-up's queue aliases an unseen thank",
       expect="thankpress: the full check-up names nobody for an unseen thank", script=S)

mutate("ThankPress.lua",
       "\t\t\tfound.shownAt = now\n",
       "",
       "thankpress: a newer buff keeps the older clock",
       expect="thankpress: a newer buff from the same giver starts the time on the prompt again", script=S)

mutate("ThankPress.lua",
       "\t\tfor key in pairs(item.keys or {}) do declinedAt[\"?\" .. tostring(key)] = now end\n",
       "",
       "thankpress: two unseen spells let go, one held back",
       expect="thankpress: unseen, two spells let go are both held back", script=S)
