# The launcher's load-bearing parts -- the clicks, the menu and what it holds
# back in a fight, the tooltip, the icon and the text, the addon compartment --
# each put back wrong and required to be caught by the scenario in
# tests/scenarios/minimap.lua written for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------------ clicks

mutate("Options.lua",
       "\tif mouseButton == \"MiddleButton\" then\n\t\tToggleEnabled()\n\t\treturn\n\tend\n",
       "",
       "minimap: a middle click that does nothing",
       expect="a middle click did not switch Manners off", script=S)

# ------------------------------------------------------------------ menu

mutate("Options.lua",
       "local MENU_SNOOZE_MINUTES = { 5, 15, 30, 60 }\n",
       "local MENU_SNOOZE_MINUTES = { 5, 15, 30 }\n",
       "minimap: no hour on the snooze menu",
       expect="no hour-long snooze", script=S)

mutate("Options.lua",
       "\tCheck(root, L[\"Enable\"], Enabled, Act(function()\n",
       "\tCheck(root, L[\"Enable\"], function() return true end, Act(function()\n",
       "minimap: an Enable checkbox that is always ticked",
       expect="the Enable checkbox does not read the switch as off", script=S)

mutate("Options.lua",
       "\tlocal list, showing = WhoIsWaiting(MENU_QUEUE_ROWS)\n",
       "\tlocal list, showing = {}, nil\n",
       "minimap: who's next lists nobody",
       expect="who's next does not list the prompt and the queue", script=S)

mutate("Options.lua",
       "\t\tRadio(effects, choice.label, function() return (ns.db.profile.prompt.effects or \"full\") == choice.key end,\n",
       "\t\tRadio(effects, choice.label, function() return choice.key == \"full\" end,\n",
       "minimap: the Effects radios read nothing",
       expect="the Effects radios do not read the setting", script=S)

# ------------------------------------------------------------------ combat

mutate("Options.lua",
       "\tif description.SetEnabled then description:SetEnabled(false) end\n",
       "",
       "minimap: held entries not greyed out in a fight",
       expect="is not greyed out in a fight", script=S)

mutate("Options.lua",
       "\t\tif InCombatLockdown() then\n\t\t\tns.addon:Print(L[\"that has to wait until after the fight",
       "\t\tif false then\n\t\t\tns.addon:Print(L[\"that has to wait until after the fight",
       "minimap: a held entry clicked in a fight runs",
       expect="Reset position ran in a fight", script=S)

mutate("Options.lua",
       "\t\tif fight then HeldForFight(choice) end\n",
       "",
       "minimap: profiles open in a fight",
       expect="the Healer profile is not greyed out in a fight", script=S)

# ------------------------------------------------------------------ who's next

mutate("Options.lua",
       "\tns.BlockPerson(entry.name)\n",
       "",
       "minimap: Skip for now that skips nobody",
       expect="Skip for now did not skip", script=S)

# The obvious wrong way to take somebody off the prompt at once: hide it. In a
# fight that is a protected call on the secure button.
mutate("Options.lua",
       "\tns.Guard(\"skip repaint\", ns.Prompt.Refresh, ns.Prompt)\n",
       "\tns.Prompt:GetButton():Hide()\n",
       "minimap: Skip for now hides the secure button",
       expect="Skip for now touched the secure button in a fight", script=S)

mutate("Options.lua",
       "\tns.PutOnNeverList(entry.name)\n",
       "",
       "minimap: Never offer that lists nobody",
       expect="Never offer did not put", script=S)

# ------------------------------------------------------------------ tooltip

mutate("Options.lua",
       "\t\t\tif entry == showing then\n\t\t\t\ttooltip:AddLine(",
       "\t\t\tif false then\n\t\t\t\ttooltip:AddLine(",
       "minimap: the tooltip never names the prompt",
       expect="the tooltip does not say who is on the prompt", script=S)

mutate("Options.lua",
       "\tif watching and InCombatLockdown() then\n",
       "\tif false then\n",
       "minimap: the tooltip never says held",
       expect="the tooltip does not say the prompt is held in a fight", script=S)

mutate("Options.lua",
       "\ttooltip:AddLine(Enabled() and L[\"Middle click: switch it off\"]\n"
       "\t\tor L[\"Middle click: switch it on\"], 0.6, 0.6, 0.6)\n",
       "",
       "minimap: the tooltip without the middle click",
       expect="the tooltip has no click hint \"Middle click", script=S)

# ------------------------------------------------------------------ at a glance

mutate("Options.lua",
       "\tif broker.iconR ~= r then broker.iconR = r end\n",
       "",
       "minimap: an icon that never dims",
       expect="the icon is not dimmed while off", script=S)

mutate("Options.lua",
       "\tif not Enabled() then return 0.45, 0.45, 0.45 end\n",
       "",
       "minimap: an icon that ignores the switch",
       expect="the icon is not dimmed while off", script=S)

mutate("Options.lua",
       "\t\t\tif ok and type(ends) == \"number\" and ends > now then n = n + 1 end\n",
       "",
       "minimap: a launcher that counts no favours",
       expect="the launcher does not count the favours waiting", script=S)

mutate("Core.lua",
       "\tif ns.RefreshBrokerText then ns.Guard(\"broker text\", ns.RefreshBrokerText) end\n",
       "",
       "minimap: a favour filed and the text left behind",
       expect="a favour filed left the launcher", script=S)

# ------------------------------------------------------------------ compartment

mutate("Options.lua",
       "\tns.Guard(\"addon compartment\", RegisterCompartment)\n",
       "",
       "minimap: never in the addon compartment",
       expect="never registered in the addon compartment", script=S)

mutate("Options.lua",
       "\tif compartment or type(frame) ~= \"table\" or type(frame.RegisterAddon) ~= \"function\" then\n",
       "\tif compartment then\n",
       "minimap: the compartment assumed",
       expect="a client without the addon compartment loads clean", script=S)

mutate("Options.lua",
       "\tif later and C_Timer and C_Timer.After then\n",
       "\tif false then\n",
       "minimap: the menu opened inside the compartment",
       expect="the menu opened inside the compartment's own click", script=S)
