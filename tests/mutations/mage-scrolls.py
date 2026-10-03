# Mutations for a mage's scrolls on WoW Forever (tests/scenarios/mage-scrolls.lua):
# the scrolls in Buffs.lua's camelot set, the bags, level, weapon and enchant
# read in Core.lua, the /use macro (Prompt/Macro.lua), the debug lines
# (Commands.lua), the rows (Options/Who.lua, Options/Window/Layout.lua) and the
# bug report (Options/Diagnostics.lua). Each is caught by the scenario that
# names it.

S = "runscenarios.py"

# --- the scrolls (Buffs.lua) ---

mutate("Buffs.lua",
       "\tcamelot = CAMELOT_SET,\n",
       "\tcamelot = VANILLA_SET,\n",
       "scrolls: not in Forever's set",
       expect="a level-12 mage with a Rat Familiar scroll and no familiar was offered", script=S)

mutate("Buffs.lua",
       "enchant = 8698, weapon = DAGGER },",
       "enchant = 8698, weapon = STAFF },",
       "scrolls: Chillknife for a staff",
       expect="with a dagger in hand you were offered", script=S)

mutate("Buffs.lua",
       "\t\t\t\tnameFromItem = true },\n",
       "\t\t\t\t},\n",
       "scrolls: Spellbreak named as Lesser Flame",
       expect="the imbues read", script=S)

# --- the probe and the bags (Core.lua) ---

# Probed as a spell: the spell's icon, and nothing known.
mutate("Core.lua",
       "\t\t\t\tlocal info = spell.item and ProbeScroll(spell) or ProbeBuff(spell)\n",
       "\t\t\t\tlocal info = ProbeBuff(spell)\n",
       "scrolls: probed as spells",
       expect="not the scroll's", script=S)

mutate("Core.lua",
       "\t\t\tinfo.name = spellName or itemName\n",
       "\t\t\tinfo.name = itemName or spellName\n",
       "scrolls: named as the item",
       expect="the reason line reads", script=S)

mutate("Core.lua",
       "\t\tif spell.item then return ScrollCount(spell) > 0 end\n",
       "",
       "scrolls: the bags never counted",
       expect="a level-12 mage with a Rat Familiar scroll and no familiar was offered", script=S)

mutate("Core.lua",
       "\t\tif not scrollCounts then\n",
       "\t\tif true then\n",
       "scrolls: the bags read on every scan",
       expect="more times over five scans", script=S)

mutate("Core.lua",
       "function addon:BAG_UPDATE_DELAYED() ns.ForgetScrolls() end\n",
       "function addon:BAG_UPDATE_DELAYED() end\n",
       "scrolls: a bag change not noticed",
       expect="after the bags changed, a Rat Familiar scroll was not offered", script=S)

mutate("Core.lua",
       "function addon:PLAYER_EQUIPMENT_CHANGED() ns.ForgetMainHand() end\n",
       "function addon:PLAYER_EQUIPMENT_CHANGED() end\n",
       "scrolls: a weapon change not noticed",
       expect="with a staff put in hand, you were offered", script=S)

mutate("Core.lua",
       "\t\t\"BAG_UPDATE_DELAYED\",\n\t\t\"PLAYER_EQUIPMENT_CHANGED\",\n",
       "",
       "scrolls: the events not registered",
       expect="the bags and the weapon in hand are not watched", script=S)

mutate("Core.lua",
       "\t\tif type(level) ~= \"number\" or level < spell.level then return false, \"level\" end\n",
       "",
       "scrolls: any level",
       expect="a level-4 mage was offered", script=S)

mutate("Core.lua",
       "\t\tif spell.weapon and MainHand() ~= spell.weapon then return false, \"weapon\" end\n",
       "",
       "scrolls: any weapon",
       expect="with a dagger in hand you were offered", script=S)

# --- reading them, and which to offer (Core.lua) ---

mutate("Core.lua",
       "\t\tif family.imbue then return ReadImbue(family) end\n",
       "",
       "scrolls: the imbue read as an aura",
       expect="with a familiar up and the imbue on, you were offered", script=S)

mutate("Core.lua",
       "\t\tif type(expires) == \"number\" and expires > 0 then left = expires / 1000 end\n",
       "\t\tif type(expires) == \"number\" and expires > 0 then left = expires end\n",
       "scrolls: the enchant's time in milliseconds",
       expect="two minutes of Lesser Flame with top-ups on offered", script=S)

mutate("Core.lua",
       "\t\tif scroll then Remember(family, scroll) end\n",
       "",
       "scrolls: the imbue on never remembered",
       expect="the imbue on the weapon was not remembered", script=S)

mutate("Core.lua",
       "\t\t\t\tif ScrollCount(spell) > 0 then return spell end\n",
       "",
       "scrolls: Spellbreak taken for Lesser Flame",
       expect="the imbue on the weapon was not remembered", script=S)

mutate("Core.lua",
       "\t\t\tif spell.item or Known(spell) then\n",
       "\t\t\tif Known(spell) then\n",
       "scrolls: a familiar read only with its scroll",
       expect="with a Frog familiar up, the Rat scroll was offered", script=S)

mutate("Core.lua",
       "and (spell.item or Known(spell)) then return spell.key, spell end\n",
       "and Known(spell) then return spell.key, spell end\n",
       "scrolls: a pick with none left reads Automatic",
       expect="a pick with none in the bags reads", script=S)

mutate("Core.lua",
       "\t\t\tand not (spell.item and not ScrollReady(spell)) then return spell end\n",
       "\t\t\tthen return spell end\n",
       "scrolls: the one used last that no longer fits",
       expect="rather than a scroll that fits it", script=S)

mutate("Core.lua",
       "\t\tif family.scroll then\n\t\t\tlocal held, heldWhy\n",
       "\t\tif false then\n\t\t\tlocal held, heldWhy\n",
       "scrolls: Automatic takes one that cannot be used",
       expect="with a dagger in hand you were offered", script=S)

mutate("Core.lua",
       "\t\t\tif not ready then return nil, up, left, why, spell end\n",
       "",
       "scrolls: a pick offered with none in the bags",
       expect="picked Cat Familiar with none in the bags, and was offered", script=S)

mutate("Core.lua",
       "\t\t\tif held and not up then return nil, up, nil, heldWhy, held end\n",
       "",
       "scrolls: why not, unsaid",
       expect="/manners debug says", script=S)

# --- the press (Prompt/Macro.lua) ---

mutate("Prompt/Macro.lua",
       "\t\tif entry.buff and entry.buff.item then return \"scroll\" end\n",
       "",
       "scrolls: cast on you by name",
       expect="the familiar's macro reads", script=S)

mutate("Prompt/Macro.lua",
       "\"/use item:\" .. tostring(entry.buff.item)",
       "\"/use \" .. tostring(entry.buff.item)",
       "scrolls: used by a bare number",
       expect="the familiar's macro reads", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.reason == \"self\" and entry.buff.item then\n",
       "\tif false then\n",
       "scrolls: the tooltip says cast",
       expect="the tooltip says", script=S)

# Settled by name: Spellbreak's use casts Lesser Flame's spell.
mutate("Clicks.lua",
       "\tif own and own.item then return own.ranks[1] == spellId end\n",
       "",
       "scrolls: Spellbreak's cast taken for another",
       expect="Spellbreak's own cast was taken for another", script=S)

# --- what is said about them (Commands.lua, Options/Diagnostics.lua) ---

mutate("Commands.lua",
       "\t\telseif why == \"up\" and not name and family.imbue then\n",
       "\t\telseif false then\n",
       "scrolls: an oil said as ? is up",
       expect="/manners debug says, of an oil", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"bags\" then\n",
       "\t\telseif false then\n",
       "scrolls: none in the bags unsaid",
       expect="/manners debug says", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"level\" then\n",
       "\t\telseif false then\n",
       "scrolls: the level unsaid",
       expect="/manners debug says", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"weapon\" then\n",
       "\t\telseif false then\n",
       "scrolls: the weapon unsaid",
       expect="/manners debug says", script=S)

mutate("Commands.lua",
       "\t\telseif spell and spell.item then\n",
       "\t\telseif false then\n",
       "scrolls: a scroll to cast",
       expect="Diagnostics says", script=S)

mutate("Options/Diagnostics.lua",
       "\tif #scrolls > 0 then lines[#lines + 1] = \"scrolls \" .. table.concat(scrolls, \" \") end\n",
       "",
       "scrolls: not in the bug report",
       expect="the bug report says nothing of the scrolls", script=S)

# --- the rows (Options/Who.lua, Options/Window/Layout.lua) ---

mutate("Options/Who.lua",
       "\treturn family.scroll or ns.OwnSpellKnown(spell)\n",
       "\treturn ns.OwnSpellKnown(spell)\n",
       "scrolls: only those in the bags listed",
       expect="the Familiar choices are", script=S)

mutate("Options/Who.lua",
       "\tif why == \"best\" then return L[\"Automatic (%s, the best you can use now)\"]:format(name) end\n",
       "",
       "scrolls: Automatic's best unsaid",
       expect="Automatic reads", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_familiar\", indent = true },\n",
       "",
       "scrolls: no Familiar row in the window",
       expect="who.own_familiar is not placed under Myself", script=S)
