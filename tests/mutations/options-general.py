# Start here (BuildStartTab in Options.lua). Each fault is caught by the
# scenario in tests/scenarios/options-general.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the layout ---

# A step header moved out of turn.
mutate("Options.lua",
       "\t\t\t\ttype = \"header\", name = L[\"3. See it\"], order = 30,\n",
       "\t\t\t\ttype = \"header\", name = L[\"3. See it\"], order = 19,\n",
       "start here: step 3 before step 2",
       expect="3. See it comes before the step ahead of it", script=S)

# The steps shown to a class with nothing to cast.
mutate("Options.lua",
       "\tlocal function noClassBuffs() return not HasClassBuffs() end\n",
       "\tlocal function noClassBuffs() return false end\n",
       "start here: steps shown without class buffs",
       expect="is shown to a class with nothing to cast", script=S)

# --- the lock ---

# The warning up over a locked prompt.
mutate("Options.lua",
       "\t\t\t\tname = \"|cffff8080\" .. L[\"The prompt is unlocked, so it will not cast.\"] .. \"|r\",\n",
       "\t\t\t\tname = \"|cffff8080\" .. L[\"The prompt is unlocked, so it will not cast.\"] .. \"|r\",\n"
       "\t\t\t\thidden = function() return not HasClassBuffs() end,\n",
       "start here: lock warning over a locked prompt",
       expect="the unlocked warning is up over a locked prompt", script=S)

# Lock it that locks nothing.
mutate("Options.lua",
       "\t\t\t\t\tP().locked = true\n\t\t\t\t\tns.Prompt:ApplyStyle()\n",
       "\t\t\t\t\tns.Prompt:ApplyStyle()\n",
       "start here: Lock it does not lock",
       expect="Lock it did not lock the prompt", script=S)

# Lock position writing nothing.
mutate("Options.lua",
       "\t\t\t\t\tP().locked = value\n\t\t\t\t\trestyle()\n",
       "\t\t\t\t\trestyle()\n",
       "start here: Lock position writes nothing",
       expect="Lock position unticked left the prompt locked", script=S)

# Unlocked while off, without a word.
mutate("Options.lua",
       "\t\t\t\t\tP().locked = value\n\t\t\t\t\trestyle()\n\t\t\t\t\tif not value and not ns.db.profile.enabled then\n",
       "\t\t\t\t\tP().locked = value\n\t\t\t\t\trestyle()\n\t\t\t\t\tif false then\n",
       "start here: unlocked while off says nothing",
       expect="unlocked while off, and chat said nothing", script=S)

# --- step 1 and step 4 ---

mutate("Options.lua",
       "\t\t\t\tset = function(_, v) Quick.Apply(Quick.WHO, v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: Offer my buff to sets nothing",
       expect="did not set it up", script=S)

mutate("Options.lua",
       "\t\t\t\tconfirm = function(_, v) return Quick.Confirm(Quick.WHO, v) end,\n",
       "",
       "start here: who preset replaces hand choices unasked",
       expect="asks nothing first", script=S)

mutate("Options.lua",
       "\t\t\t\tset = function(_, v) Quick.Apply(Quick.VOICE, v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: When I buff someone back sets nothing",
       expect="picking Just /thank them did not set it up", script=S)

# --- step 2 ---

mutate("Options.lua",
       "\t\t\t\tset = function(_, v) Setup.SetKey(v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: the key control binds nothing",
       expect="the key picked was not bound to the prompt", script=S)

mutate("Options.lua",
       "\t\t\t\t-- SetBinding is refused in a fight.\n\t\t\t\tdisabled = function() return InCombatLockdown() end,\n",
       "\t\t\t\t-- SetBinding is refused in a fight.\n",
       "start here: the key control live in a fight",
       expect="the key control is live in a fight", script=S)

mutate("Options.lua",
       "\t\t\t\t\telseif Setup.MacroMade() then\n",
       "\t\t\t\t\telseif false then\n",
       "start here: key status blind to the macro",
       expect="with the macro made, the status reads", script=S)

mutate("Options.lua",
       "\t\t\t\t\tif key then\n\t\t\t\t\t\tlocal shown",
       "\t\t\t\t\tif false then\n\t\t\t\t\t\tlocal shown",
       "start here: key status blind to the key",
       expect="with a key bound, the status reads", script=S)

mutate("Options.lua",
       "\t\t\t\t\tns.CreateClickMacro()\n\t\t\t\t\tns.RefreshOptionsDisplay()\n",
       "\t\t\t\t\tns.RefreshOptionsDisplay()\n",
       "start here: Make a macro makes nothing",
       expect="Make a macro made nothing", script=S)

# --- step 3 ---

mutate("Options.lua",
       "\t\t\t\t\treturn ns.Prompt:InTest() and L[\"Stop preview\"] or L[\"Show me the prompt\"]\n",
       "\t\t\t\t\treturn L[\"Show me the prompt\"]\n",
       "start here: preview button never says stop",
       expect="with a preview up, the button reads", script=S)

mutate("Options.lua",
       "\t\t\t\t\treturn InCombatLockdown() and not ns.Prompt:InTest()\n\t\t\t\tend,\n\t\t\t\tfunc = function() ns.Prompt:ToggleTest() end,\n\t\t\t},\n\t\t\tstartPos",
       "\t\t\t\t\treturn false\n\t\t\t\tend,\n\t\t\t\tfunc = function() ns.Prompt:ToggleTest() end,\n\t\t\t},\n\t\t\tstartPos",
       "start here: preview startable in a fight",
       expect="the preview can be started in a fight", script=S)

mutate("Options.lua",
       "\t\t\t\t\tif not ns.CurrentPositionPreset() then out.custom = L[\"Where I dragged it\"] end\n",
       "\t\t\t\t\tout.custom = L[\"Where I dragged it\"]\n",
       "start here: Where I dragged it always offered",
       expect="Where I dragged it is offered while the prompt is on a preset", script=S)

mutate("Options.lua",
       "\t\t\t\t\tif not ns.CurrentPositionPreset() then keys[#keys + 1] = \"custom\" end\n",
       "",
       "start here: Where I dragged it not last",
       expect="Where I dragged it is not the last choice once dragged", script=S)

mutate("Options.lua",
       "\t\t\t\t\tns.ApplyPositionPreset(v)\n\t\t\t\t\trestyle()\n",
       "\t\t\t\t\trestyle()\n",
       "start here: Where it sits moves nothing",
       expect="picking Under the minimap did not move the prompt", script=S)

mutate("Options.lua",
       "\t\t\t\tget = function() return ns.CurrentPositionPreset() or \"custom\" end,\n",
       "\t\t\t\tget = function() return ns.CurrentPositionPreset() or \"bars\" end,\n",
       "start here: dragged prompt shown on a preset",
       expect="dragged off the presets, the dropdown still names one", script=S)

# --- snooze ---

mutate("Options.lua",
       "\t\t\t\tfunc = function() ns.StartSnooze(ns.SNOOZE_CHOICES[1]) end,\n",
       "\t\t\t\tfunc = function() end,\n",
       "start here: 5-minute snooze does nothing",
       expect="the 5-minute button did not snooze", script=S)
