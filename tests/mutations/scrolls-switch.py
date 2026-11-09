# Mutations for the Scrolls switch under Myself (Buffs.lua isScroll, Core.lua
# ns.ScrollsOff, OwnPick and Known, Options/Who.lua ownScrolls and the rows'
# hidden rule, Commands.lua's line, the layout slot and keywords, the page's
# reset). Each is caught by the scenario in tests/scenarios/scrolls-switch.lua
# (or layout.lua, model-window.lua) that names it.

S = "runscenarios.py"

# --- the default --------------------------------------------------------------------

mutate("Core.lua",
       "\t\t\tscrolls = true,\n",
       "\t\t\tscrolls = false,\n",
       "scrolls-switch: off by default",
       expect="scrolls-switch: camelot: on by default", script=S)

mutate("Buffs.lua",
       "\t\t\tisScroll = prefix == \"scroll\" or nil }\n",
       "\t\t\tisScroll = nil }\n",
       "scrolls-switch: the stat scrolls not marked",
       expect="scrolls-switch: era: off, no stat scroll is offered or shown", script=S)

mutate("Buffs.lua",
       "\t\tlabel = L[\"Familiar\"],\n\t\tscroll = true,\n\t\tisScroll = true,\n",
       "\t\tlabel = L[\"Familiar\"],\n\t\tscroll = true,\n",
       "scrolls-switch: the familiar not marked",
       expect="scrolls-switch: forever: off, a mage's familiar and a stat scroll are gone and kept", script=S)

# --- nothing offered ------------------------------------------------------------------

mutate("Core.lua",
       "\t\tif ns.ScrollsOff(family) then return \"off\" end\n\t\tif pick == \"off\" then return \"off\" end\n",
       "\t\tif pick == \"off\" then return \"off\" end\n",
       "scrolls-switch: a stat scroll's pick ignores the switch",
       expect="scrolls-switch: era: off, no stat scroll is offered or shown", script=S)

mutate("Core.lua",
       "\t\tif spell.item and ns.ScrollsOff(spell.family) then return false end\n",
       "",
       "scrolls-switch: a familiar in the bags still known with the switch off",
       expect="scrolls-switch: forever: off, a mage's familiar and a stat scroll are gone and kept", script=S)

mutate("Core.lua",
       "\t\treturn type(own) == \"table\" and own.scrolls == false\n",
       "\t\treturn false\n",
       "scrolls-switch: the switch read nowhere",
       expect="scrolls-switch: forever: off, a mage's familiar and a stat scroll are gone and kept", script=S)

# --- the page -------------------------------------------------------------------------

mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.ScrollsOff(family) then return true end\n",
       "",
       "scrolls-switch: a stat scroll's row stays with the switch off",
       expect="scrolls-switch: era: off, no stat scroll is offered or shown", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.scrolls = value == true\n",
       "",
       "scrolls-switch: the switch writes nothing",
       expect="scrolls-switch: forever: off, a mage's familiar and a stat scroll are gone and kept", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t-- The bags are counted again for the scrolls switched on.\n"
       "\t\t\t\t\tif ns.ForgetScrolls then ns.ForgetScrolls() end\n",
       "",
       "scrolls-switch: the bags not counted again when it is turned on",
       expect="scrolls-switch: era: off, no stat scroll is offered or shown", script=S)

mutate("Options/Who.lua",
       "\tif ns.db.profile.ownBuffs.scrolls == false then return true end\n",
       "",
       "scrolls-switch: the switch hides itself once off",
       expect="scrolls-switch: the switch shows only with a scroll about", script=S)

mutate("Options/Who.lua",
       "\tfor _, family in ipairs(ns.KnownOwnFamilies()) do\n\t\tif family.isScroll then return true end\n\tend\n\treturn false\n",
       "\treturn true\n",
       "scrolls-switch: the switch shown with no scroll about",
       expect="scrolls-switch: the switch shows only with a scroll about", script=S)

mutate("Core.lua",
       "\t\t\tif family.isScroll then return true end\n\t\tend\n\t\treturn false\n\tend\n\n\t-- Nothing outside these",
       "\t\t\tif family.isScroll then return true end\n\t\tend\n\t\treturn true\n\tend\n\n\t-- Nothing outside these",
       "scrolls-switch: retail said to have scrolls",
       expect="scrolls-switch: retail has no scroll and no switch", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownScrolls\", indent = true },\n",
       "",
       "scrolls-switch: the switch not placed on the page",
       expect="ownScrolls", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"who.ownScrolls\"] = L[\"hide familiar imbue\"],\n",
       "",
       "scrolls-switch: no search words for the switch",
       expect="scrolls-switch: the switch shows only with a scroll about", script=S)

mutate("Options/Advanced.lua",
       "\"ownBuffs.scrolls\", \"groupBuffs.use\",",
       "\"groupBuffs.use\",",
       "scrolls-switch: the page's reset leaves the switch",
       expect="model: the reset puts who back", script=S)

# --- /manners debug -------------------------------------------------------------------

mutate("Commands.lua",
       "\t\tif scrollsOff then\n",
       "\t\tif false then\n",
       "scrolls-switch: debug quiet about the switch",
       expect="/manners debug does not say Scrolls is off", script=S)

mutate("Commands.lua",
       "and #ns.SelfBuffs() == 0 and not scrollsOff then return out end\n",
       "and #ns.SelfBuffs() == 0 then return out end\n",
       "scrolls-switch: debug quiet about the switch when nothing else is yours",
       expect="/manners debug does not say Scrolls is off", script=S)
