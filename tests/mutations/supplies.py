# Mutations for the consumables button (Prompt/Supplies.lua; Queue.lua,
# OwnPick, ns.SupplyEntry; Prompt/Macro.lua, ns.ItemMacro). Each is caught by
# the scenario in tests/scenarios/supplies.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tapart = false,\n",
       "\t\t\tapart = true,\n",
       "supplies: on by default",
       expect="supplies: off by default, food stays on the prompt", script=S)

mutate("Queue.lua",
       "\t\tif not (apart and ns.ItemFamily(family)) then\n",
       "\t\tif true then\n",
       "supplies: food stays on the prompt as well",
       expect="supplies: on, food leaves the prompt for the button", script=S)

mutate("Prompt/Supplies.lua",
       "\tif not ns.ItemsApart(db) then\n\t\tif button then\n",
       "\tif false then\n\t\tif button then\n",
       "supplies: the button offers with the switch off",
       expect="supplies: on, food leaves the prompt for the button", script=S)

mutate("Queue.lua",
       "\t\tif spell.item then return true end\n",
       "",
       "supplies: no family counts as items",
       expect="supplies: on, food leaves the prompt for the button", script=S)

mutate("Prompt/Supplies.lua",
       "\tns.MarkAttempted(current.name, current.buff.key)\n\tns.NoteScrollPress(current.buff)\n",
       "\tns.NoteScrollPress(current.buff)\n",
       "supplies: a press writes no block",
       expect="supplies: a press holds the food back", script=S)

mutate("Prompt/Supplies.lua",
       "\tns.MarkAttempted(current.name, current.buff.key, ns.SkipSeconds())\n",
       "\tns.MarkAttempted(current.name, current.buff.key, 1)\n",
       "supplies: a right-click skips for a second",
       expect="supplies: a right-click skips it for the skip time", script=S)

mutate("Prompt/Supplies.lua",
       "\tif not db.prompt.locked then\n\t\tDisarm()\n",
       "\tif not db.prompt.locked then\n",
       "supplies: armed while unlocked",
       expect="supplies: unlocked it shows, arms nothing, and a drag keeps its place", script=S)

mutate("Prompt/Supplies.lua",
       "\t\tself:StopMovingOrSizing()\n\t\tSavePosition()\n",
       "\t\tself:StopMovingOrSizing()\n",
       "supplies: a drag is not kept",
       expect="supplies: unlocked it shows, arms nothing, and a drag keeps its place", script=S)

mutate("Prompt/Supplies.lua",
       "\tif macro == armedMacro and button:GetAttribute(\"macrotext1\") == macro then return end\n",
       "\tif macro == armedMacro then return end\n",
       "supplies: not armed again after a fight",
       expect="supplies: a fight takes it away, disarmed, and the end of it brings it back", script=S)

mutate("Prompt/Supplies.lua",
       "\t\tbutton:SetAttribute(\"macrotext1\", nil)\n\t\tbutton:SetAttribute(\"type\", nil)\n\t\tbutton:SetAttribute(\"macrotext\", nil)\n\t\tbutton:Hide(true)\n",
       "\t\tbutton:Hide(true)\n",
       "supplies: the snippet hides it still armed",
       expect="supplies: the fight's snippet disarms and hides it on its own", script=S)

mutate("Prompt/Supplies.lua",
       "\t\t\t_G.RegisterStateDriver(made, STATE, DRIVER)\n",
       "",
       "supplies: no driver for the fight",
       expect="supplies: the fight's snippet disarms and hides it on its own", script=S)

mutate("Core.lua",
       "\tif supplies and supplies:Wanted() then ns.Guard(\"consumables button\", supplies.Refresh, supplies, now) end\n",
       "",
       "supplies: never repainted",
       expect="supplies: on, food leaves the prompt for the button", script=S)

mutate("Core.lua",
       "\t{ \"supplies\", \"size\", 24, 80 },\n",
       "",
       "supplies: a size out of bounds kept",
       expect="supplies: the switch is under Myself", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.apart = value == true\n",
       "",
       "supplies: the switch stores nothing",
       expect="supplies: the switch is under Myself", script=S)
