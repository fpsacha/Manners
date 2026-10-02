# Start here (BuildStartTab in Options.lua). Each fault is caught by the
# scenario in tests/scenarios/options-general.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the layout ---

# A step header moved out of turn. Re-anchored on step 2: step 3 is the
# window's header button now, and Start here has two steps.
mutate("Options/Start.lua",
       "\t\t\t\ttype = \"header\", name = L[\"2. Put it on a key\"], order = 20,\n",
       "\t\t\t\ttype = \"header\", name = L[\"2. Put it on a key\"], order = 9,\n",
       "start here: step 2 before step 1",
       expect="2. Put it on a key comes before the step ahead of it", script=S)

# The steps shown to a class with nothing to cast.
mutate("Options/Start.lua",
       "\tlocal function noClassBuffs() return not HasClassBuffs() end\n",
       "\tlocal function noClassBuffs() return false end\n",
       "start here: steps shown without class buffs",
       expect="is shown to a class with nothing to cast", script=S)

# --- the lock ---

# The warning up over a locked prompt. Re-anchored on Lock it: the warning
# itself is the status strip's line now, the launcher's own.
mutate("Options/Start.lua",
       "\t\t\t\thidden = function() return P().locked or not HasPrompt() end,\n"
       "\t\t\t\tfunc = function()\n",
       "\t\t\t\thidden = function() return not HasPrompt() end,\n"
       "\t\t\t\tfunc = function()\n",
       "start here: lock warning over a locked prompt",
       expect="the unlocked warning is up over a locked prompt", script=S)

# Lock it that locks nothing.
mutate("Options/Start.lua",
       "\t\t\t\t\tP().locked = true\n\t\t\t\t\tns.Prompt:ApplyStyle()\n",
       "\t\t\t\t\tns.Prompt:ApplyStyle()\n",
       "start here: Lock it does not lock",
       expect="Lock it did not lock the prompt", script=S)

# Lock position writing nothing. Re-anchored on Look's: Start here's copy
# (startLocked) is gone.
mutate("Options/Look.lua",
       "\t\t\t\t\tpSet(info, value)\n\t\t\t\t\tif not value and not ns.db.profile.enabled then\n",
       "\t\t\t\t\tif not value and not ns.db.profile.enabled then\n",
       "start here: Lock position writes nothing",
       expect="Lock position unticked left the prompt locked", script=S)

# Unlocked while off, without a word.
mutate("Options/Look.lua",
       "\t\t\t\t\tpSet(info, value)\n\t\t\t\t\tif not value and not ns.db.profile.enabled then\n",
       "\t\t\t\t\tpSet(info, value)\n\t\t\t\t\tif false then\n",
       "start here: unlocked while off says nothing",
       expect="unlocked while off, and chat said nothing", script=S)

# --- step 1 and step 4 ---

mutate("Options/Start.lua",
       "\t\t\t\tset = function(_, v) Quick.Apply(Quick.WHO, v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: Offer my buff to sets nothing",
       expect="did not set it up", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tconfirm = function(_, v) return Quick.Confirm(Quick.WHO, v) end,\n",
       "",
       "start here: who preset replaces hand choices unasked",
       expect="asks nothing first", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tset = function(_, v) Quick.Apply(Quick.VOICE, v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: When I buff someone back sets nothing",
       expect="picking Just /thank them did not set it up", script=S)

# --- step 2 ---

mutate("Options/Start.lua",
       "\t\t\t\tset = function(_, v) Setup.SetKey(v) end,\n",
       "\t\t\t\tset = function() end,\n",
       "start here: the key control binds nothing",
       expect="the key picked was not bound to the prompt", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t-- SetBinding is refused in a fight.\n\t\t\t\tdisabled = function() return InCombatLockdown() end,\n",
       "\t\t\t\t-- SetBinding is refused in a fight.\n",
       "start here: the key control live in a fight",
       expect="the key control is live in a fight", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\telseif Setup.MacroMade() then\n",
       "\t\t\t\t\telseif false then\n",
       "start here: key status blind to the macro",
       expect="with the macro made, the status reads", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\tif key then\n\t\t\t\t\t\tlocal shown",
       "\t\t\t\t\tif false then\n\t\t\t\t\t\tlocal shown",
       "start here: key status blind to the key",
       expect="with a key bound, the status reads", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\tns.CreateClickMacro()\n\t\t\t\t\tif Setup.MacroMade() then Setup.OpenMacros() end\n",
       "\t\t\t\t\tif Setup.MacroMade() then Setup.OpenMacros() end\n",
       "start here: Make a macro makes nothing",
       expect="Make a macro made nothing", script=S)

# The macro made, and the macro window left shut.
mutate("Options/Start.lua",
       "\t\t\t\t\tif Setup.MacroMade() then Setup.OpenMacros() end\n",
       "",
       "start here: macro window not opened",
       expect="Make a macro did not open the macro window", script=S)

mutate("Options/Start.lua",
       "\tif InCombatLockdown() or type(ShowMacroFrame) ~= \"function\" then return false end\n",
       "\tif type(ShowMacroFrame) ~= \"function\" then return false end\n",
       "start here: macro window opened in combat",
       expect="the macro window opened in combat", script=S)

# The made-macro line not saying where the macro is.
mutate("Options/Start.lua",
       "L[\"Your Manners macro is made: open the macro window (/macro) and drag it onto an action bar.\"]",
       "L[\"Your Manners macro is made; drag it onto an action bar.\"]",
       "start here: made macro, nowhere to drag from",
       expect="the made-macro line does not say where to drag it from", script=S)

# --- minimap and chat ---

mutate("Options/Start.lua",
       "\t\t\tminimapHeader = { type = \"header\", name = L[\"Minimap and chat\"], order = 69 },\n",
       "",
       "start here: minimap switch under the ledger header",
       expect="there is no Minimap and chat header", script=S)

mutate("Options/Start.lua",
       "\t\t\t\torder = 71,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = function() return ns.db.profile.verbose end,\n",
       "\t\t\t\torder = 65,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = function() return ns.db.profile.verbose end,\n",
       "start here: chat switch out of its section",
       expect="the minimap and chat switches are not under their header", script=S)

# --- the shared profile ---

mutate("Options/Start.lua",
       "\t\t\t\torder = 8,\n\t\t\t\thidden = function() return Setup.SharedWith() == 0 end,\n",
       "\t\t\t\torder = 8,\n\t\t\t\thidden = function() return true end,\n",
       "start here: a shared profile not said",
       expect="a profile two characters share is not said", script=S)

mutate("Options/Start.lua",
       "\t\tif profile == current and char ~= keys.char then n = n + 1 end\n",
       "\t\tif profile == current then n = n + 1 end\n",
       "start here: a profile of its own counted as shared",
       expect="the shared-profile line shows with nobody else on the profile", script=S)

mutate("Options/Start.lua",
       "\tif InCombatLockdown() or not (db.SetProfile and db.CopyProfile and db.GetCurrentProfile\n",
       "\tif not (db.SetProfile and db.CopyProfile and db.GetCurrentProfile\n",
       "start here: own profile made in combat",
       expect="the profile was switched in combat", script=S)

mutate("Options/Start.lua",
       "\t\tdb:CopyProfile(shared)\n",
       "",
       "start here: own profile starts from the defaults",
       expect="the button did not give this character a copy", script=S)

# --- step 3 ---

mutate("Options/Start.lua",
       "\t\t\t\t\treturn ns.Prompt:InTest() and L[\"Stop preview\"] or L[\"Show me the prompt\"]\n",
       "\t\t\t\t\treturn L[\"Show me the prompt\"]\n",
       "start here: preview button never says stop",
       expect="with a preview up, the button reads", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\treturn not ns.Prompt:InTest() and InCombatLockdown()\n",
       "\t\t\t\t\treturn false\n",
       "start here: preview startable in a fight",
       expect="the preview can be started in a fight", script=S)

# Retired: "start here: Where I dragged it always offered", "... not last" and
# "dragged prompt shown on a preset". Start here's copy of Where it sits
# (startPos) is gone; Look's posPreset is the one, held by the look: mutations
# in options-appearance.py.

# Where it sits moving nothing. Re-anchored on Look's, the only one left.
mutate("Options/Look.lua",
       "\t\t\t\t\tif value ~= \"custom\" then ns.ApplyPositionPreset(value) end\n",
       "",
       "start here: Where it sits moves nothing",
       expect="picking the default place did not put the prompt back", script=S)

# --- snooze ---

mutate("Options/Start.lua",
       "\t\t\t\tfunc = function() ns.StartSnooze(ns.SNOOZE_CHOICES[1]) end,\n",
       "\t\t\t\tfunc = function() end,\n",
       "start here: 5-minute snooze does nothing",
       expect="the 5-minute button did not snooze", script=S)
