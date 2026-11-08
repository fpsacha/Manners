# Mutations for bug hunt 38's options-window fixes:
# tests/scenarios/window-fixes38.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one finding back
# and names the scenario that objects.

S = "runscenarios.py"

# --- O1: Show every error -----------------------------------------------------

mutate("Options/Diagnostics.lua",
       "\t\t\t\tfunc = function() ns.addon:HandleSlash(\"errors all\") end,\n",
       "\t\t\t\tfunc = function() ns.addon:HandleSlash(\"errors\") end,\n",
       "window-fixes38: Show every error lists the last five",
       expect="window-fixes38: Show every error lists every one kept", script=S)

mutate("Commands.lua",
       "\t\tlocal from = rest:lower() == \"all\" and 1 or math.max(1, kept - 4)\n",
       "\t\tlocal from = math.max(1, kept - 4)\n",
       "window-fixes38: /manners errors all lists the last five",
       expect="window-fixes38: Show every error lists every one kept", script=S)

# --- O2: the Right now line ---------------------------------------------------

mutate("Options/Window/Window.lua",
       "\t\t\t\tand UI.Shown() then\n\t\t\t\tns.Guard(\"options repaint\", UI.Refresh)\n",
       "\t\t\t\tand false then\n\t\t\t\tns.Guard(\"options repaint\", UI.Refresh)\n",
       "window-fixes38: the Right now line painted once and left",
       expect="window-fixes38: the Right now line follows the prompt", script=S)

mutate("Options/Shared.lua",
       "\t\tif watching == false and type(line) == \"string\" and line ~= \"\" then\n",
       "\t\tif false then\n",
       "window-fixes38: an unlocked prompt read as nobody about",
       expect="window-fixes38: the Right now line follows the prompt", script=S)

mutate("Options/Shared.lua",
       "\t\tif InCombatLockdown() then\n\t\t\treturn \"|cff888888\" .. L[\"Right now: nobody, and nobody new",
       "\t\tif false then\n\t\t\treturn \"|cff888888\" .. L[\"Right now: nobody, and nobody new",
       "window-fixes38: a fight read as nobody about",
       expect="window-fixes38: the Right now line follows the prompt", script=S)

# --- O3: Quick setup as step 1 ------------------------------------------------

mutate("Options/Start.lua",
       "type = \"header\", name = L[\"1. Quick setup\"], order = 0.1,",
       "type = \"header\", name = L[\"Quick setup\"], order = 0.1,",
       "window-fixes38: Quick setup unnumbered over step 2",
       expect="window-fixes38: Quick setup is step 1 while it asks", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tdesc = L[\"Leaves every setting as it is. You can make the same choices later on %s and %s.\"]\n"
       "\t\t\t\t\t:format(TAB.who, TAB.click),\n",
       "\t\t\t\tdesc = L[\"Leaves every setting as it is. The same choices are below and on the other tabs.\"],\n",
       "window-fixes38: Not now promises the choices below",
       expect="window-fixes38: Quick setup is step 1 while it asks", script=S)

# --- O4: search after a non-ASCII quote ---------------------------------------

mutate("Options/Window/Search.lua",
       "\treturn MARKS[text:sub(at - 2, at - 1)] == true or MARKS[text:sub(at - 3, at - 1)] == true\n",
       "\treturn false\n",
       "window-fixes38: a quote that is not ASCII never starts a word",
       expect="window-fixes38: search finds a word after a non-ASCII quote", script=S)

# --- O5: a greyed control's tooltip -------------------------------------------

mutate("Options/Window/Widgets.lua",
       "\tif off and desc and W.Trim(off) == W.Trim(desc) then off = nil end\n",
       "",
       "window-fixes38: the tooltip says why twice",
       expect="window-fixes38: a greyed control's tooltip says its reason once", script=S)

# --- O6: What Manners can see says why ----------------------------------------

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\telseif type(class) ~= \"string\" or class == \"\" then\n",
       "\t\t\t\t\telseif false then\n",
       "window-fixes38: a class not read said as nothing to report",
       expect="window-fixes38: What Manners can see says why there is nothing", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\telseif not (ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class]) then\n",
       "\t\t\t\t\telseif false then\n",
       "window-fixes38: a class Manners does not list said as nothing to report",
       expect="window-fixes38: What Manners can see says why there is nothing", script=S)

# --- B2: the flask switch -----------------------------------------------------

mutate("Options/Who.lua",
       "\t\thidden = function() return not HasPrompt() and not Page.OwnSwitchWaiting() end,\n",
       "\t\thidden = function() return not HasPrompt() end,\n",
       "window-fixes38: Who to buff hidden from a death knight with a flask",
       expect="window-fixes38: a retail death knight reaches the flask switch", script=S)

mutate("Options/Who.lua",
       "\treturn #ns.SelfBuffs() == 0 and #ns.KnownOwnFamilies() == 0 and not Page.BaggedSwitchShown()\n",
       "\treturn #ns.SelfBuffs() == 0 and #ns.KnownOwnFamilies() == 0\n",
       "window-fixes38: Myself hidden from a paladin with a flask",
       expect="window-fixes38: a retail paladin without Beacon reaches the flask switch", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\t\tif Page.OwnSwitchWaiting() then\n",
       "\t\t\t\t\t\tif false then\n",
       "window-fixes38: Start here never says where the flask switch is",
       expect="window-fixes38: a retail death knight reaches the flask switch", script=S)

# --- T5-T7: the words ---------------------------------------------------------

mutate("Commands.lua",
       "help = L[\"hide all Manners messages in your chat window, or show them again\"] },",
       "help = L[\"say nothing at all in chat, or talk again\"] },",
       "window-fixes38: the quiet help in the old label's words",
       expect="window-fixes38: the quiet help names the switch as it reads", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t:format(L[\"Myself\"], TAB.who),\n",
       "\t\t\t\t\t:format(L[\"Myself\"], L[\"Myself\"]),\n",
       "window-fixes38: Offer nothing in cities and inns says under Myself alone",
       expect="window-fixes38: Offer nothing in cities and inns names the page Myself is on", script=S)

mutate("Options/Look.lua",
       "\t\t\t\t\t\t:format(L[\"Where the colour shows\"]) .. \"|r\"\n",
       "\t\t\t\t\t\t:format(\"the marker\") .. \"|r\"\n",
       "window-fixes38: the colour-left note names a marker",
       expect="window-fixes38: the colour-left note names the setting, not a marker", script=S)
