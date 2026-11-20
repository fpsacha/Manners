# Mutations for Don't thank anybody while I'm in a party or a raid
# (prompt.thankNotInGroup: Favours.lua, Held; Core.lua's default; Options/Say.lua;
# the layout). Each is caught by the scenario in tests/scenarios/thanknogroup.lua
# that names it.

S = "runscenarios.py"

OFF = "thanknogroup: off by default, a party member's buff is thanked"
PARTY = "thanknogroup: on in a party outdoors, no emote and the skip says in a party or a raid"
RAID = "thanknogroup: on in a raid outdoors, a stranger's buff gets no emote"
BATTLE = "thanknogroup: in a battleground Thank people there still thanks your team"
SHOWN = "thanknogroup: shown on What I say, greyed with both thank switches off"

# ------------------------------------------------ the guard
mutate("Favours.lua",
       "\t\tif p and p.thankNotInGroup == true and not ns.InBattleground()\n",
       "\t\tif false and not ns.InBattleground()\n",
       "thanknogroup: the guard is gone",
       expect=PARTY, script=S)

mutate("Favours.lua",
       "\t\t\tand (plain(_G.IsInRaid and _G.IsInRaid()) == true\n\t\t\t\tor plain(_G.IsInGroup and _G.IsInGroup()) == true) then\n",
       "\t\t\tand (plain(_G.IsInGroup and _G.IsInGroup()) == true) then\n",
       "thanknogroup: a raid is not a group",
       expect=RAID, script=S)

mutate("Favours.lua",
       "\t\t\tand (plain(_G.IsInRaid and _G.IsInRaid()) == true\n\t\t\t\tor plain(_G.IsInGroup and _G.IsInGroup()) == true) then\n",
       "\t\t\tand (plain(_G.IsInRaid and _G.IsInRaid()) == true) then\n",
       "thanknogroup: a party is not a group",
       expect=PARTY, script=S)

mutate("Favours.lua",
       "\t\tif p and p.thankNotInGroup == true and not ns.InBattleground()\n",
       "\t\tif p and p.thankNotInGroup == true\n",
       "thanknogroup: a battleground is held too",
       expect=BATTLE, script=S)

# ------------------------------------------------ the setting
mutate("Favours.lua",
       "\t\tif p and p.thankNotInGroup == true and not ns.InBattleground()\n",
       "\t\tif p and p.thankNotInGroup ~= false and not ns.InBattleground()\n",
       "thanknogroup: a missing setting reads as on",
       expect=OFF, script=S)

mutate("Core.lua",
       "\t\t\tthankNotInGroup = false,\n",
       "\t\t\tthankNotInGroup = true,\n",
       "thanknogroup: on by default",
       expect=OFF, script=S)

# ------------------------------------------------ the options window
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"click.thankNotInGroup\", indent = true },\n",
       "",
       "thanknogroup: the switch has no place on What I say",
       expect=SHOWN, script=S)

# ------------------------------------------------ the settings string
mutate("Commands.lua",
       "\t\t[\"prompt.thankNotInGroup\"] = true,\n",
       "",
       "thanknogroup: a pasted string can switch it off",
       expect="thanknogroup: a pasted string can switch it on, never off", script=S)
