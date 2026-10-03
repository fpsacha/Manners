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
       "\t\t\t\tnameFromItem = L[\"Imbue Spellbreak\"] },\n",
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
       "\t\t\tinfo.name = SpellNameFor(spell.ranks[1]) or itemName\n",
       "\t\t\tinfo.name = itemName or SpellNameFor(spell.ranks[1])\n",
       "scrolls: named as the item",
       expect="the reason line reads", script=S)

# Spellbreak before the client has loaded its item: the spell's name, which
# is Lesser Flame's; never asked for; or the item's name never taken.
mutate("Core.lua",
       "\t\t\tinfo.name = itemName or spell.nameFromItem\n",
       "\t\t\tinfo.name = itemName or SpellNameFor(spell.ranks[1])\n",
       "scrolls: Spellbreak unloaded named as Lesser Flame",
       expect="before the item loaded, Spellbreak reads", script=S)

mutate("Core.lua",
       "\t\t\t\tsafecall(items and items.RequestLoadItemDataByID, spell.item)\n",
       "",
       "scrolls: Spellbreak's item never asked for",
       expect="the Spellbreak item was never asked for", script=S)

mutate("Core.lua",
       "\tif info and info.itemPending then ns.ResolveItemName(info) end\n",
       "",
       "scrolls: Spellbreak's item name never taken",
       expect="once the item loaded, Spellbreak reads", script=S)

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

# The top-up only ever the scroll named for the enchant: the last Spellbreak
# used, and nothing offered while it ran low with Lesser Flames in the bags.
mutate("Core.lua",
       "\t\t\tif spell.item and spell.enchant and not ScrollReady(spell) then\n",
       "\t\t\tif false then\n",
       "scrolls: no top-up from the other scroll",
       expect="mage-scrolls: a top-up uses the other scroll that makes the same enchant", script=S)

# Any scroll in the bags taken for a twin: Lesser Flame offered over Frost.
mutate("Core.lua",
       "\t\t\t\t\tif twin ~= spell and twin.enchant == spell.enchant and ScrollReady(twin) then\n",
       "\t\t\t\t\tif twin ~= spell and ScrollReady(twin) then\n",
       "scrolls: a top-up from another enchant",
       expect="mage-scrolls: a top-up uses the other scroll that makes the same enchant", script=S)

mutate("Core.lua",
       "\t\tif scroll then Remember(family, scroll) end\n",
       "",
       "scrolls: the imbue on never remembered",
       expect="the imbue on the weapon was not remembered", script=S)

# Which of two scrolls making the same enchant is on: the first in the table
# (Spellbreak) rather than the one pressed, the one had on last, the one
# that can be used or the one the level allows.
mutate("Core.lua",
       "\t\tif pressed and pressed.enchant == enchant then return pressed end\n",
       "",
       "scrolls: the scroll pressed not told from its twin",
       expect="a Lesser Flame used from the prompt with a Spellbreak in the bags was remembered as", script=S)

mutate("Core.lua",
       "\t\tif memory and memory.family == family and memory.enchant == enchant and memory.level <= level then\n",
       "\t\tif false then\n",
       "scrolls: the imbue had on last not told from its twin",
       expect="a level-50 mage's Lesser Flame from before a reload", script=S)

mutate("Core.lua",
       "\t\t\t\tif ScrollReady(spell) then return spell end\n",
       "",
       "scrolls: Spellbreak taken for Lesser Flame",
       expect="a level-50 mage with Lesser Flame alone in the bags", script=S)

mutate("Core.lua",
       "\t\treturn reached or first\n",
       "\t\treturn first\n",
       "scrolls: a scroll above your level taken for the imbue on",
       expect="a level-20 mage's last Lesser Flame, with a Spellbreak left, was remembered as", script=S)

# The press noted when it settles, and put back when its cast is cut short.
mutate("Clicks.lua",
       "\t\t\tbefore = ns.NoteScrollPress(own) }\n",
       "\t\t\tbefore = nil }\n",
       "scrolls: the scroll pressed never noted",
       expect="a Lesser Flame used from the prompt with a Spellbreak in the bags was remembered as", script=S)

mutate("Clicks.lua",
       "\tRewindClick(cast.record)\n\tns.UndoScrollPress(cast.spell, cast.before)\n",
       "\tRewindClick(cast.record)\n",
       "scrolls: a press cut short still noted",
       expect="after a Spellbreak press cut short, the Lesser Flame on was remembered as", script=S)

# A familiar read best first again: all three, whatever the level, and
# without the one had up last first.
mutate("Core.lua",
       "\t\tif family.scroll then\n\t\t\tif type(byId) ~= \"function\" then return nil end\n",
       "\t\tif false then\n\t\t\tif type(byId) ~= \"function\" then return nil end\n",
       "scrolls: a familiar read only with its scroll",
       expect="with a Frog familiar up, the Rat scroll was offered", script=S)

mutate("Core.lua",
       "\t\t\telseif spell == last or spell.level > level then\n",
       "\t\t\telseif spell == last then\n",
       "scrolls: familiars above your level read",
       expect="a level-12 mage's Rat familiar took", script=S)

mutate("Core.lua",
       "\t\t\tif i == 0 then\n\t\t\t\tspell = last\n\t\t\telseif spell == last or spell.level > level then\n",
       "\t\t\tif i == 0 then\n\t\t\t\tspell = nil\n\t\t\telseif spell.level > level then\n",
       "scrolls: the familiar had up last not read first",
       expect="the one he had up last, took", script=S)

# Without the list (C_Item.GetWeaponEnchantInfo): the weapon read with the
# deprecated shim, or with neither old call.
mutate("Core.lua",
       "\t\tlocal api = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo\n",
       "\t\tlocal api = nil\n",
       "scrolls: the weapon read with the deprecated shim",
       expect="GetWeaponEnchantInfo was asked", script=S)

mutate("Core.lua",
       "\t\t\tif info == nil then return false end\n",
       "\t\t\tif info == nil then return nil end\n",
       "scrolls: no enchant read as no answer",
       expect="with GetTemporaryEnchantmentInfo first and a bare staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\tlocal read = _G.GetWeaponEnchantInfo\n\t\t\tif type(read) ~= \"function\" then return nil end\n",
       "\t\t\tdo return nil end\n\t\t\tlocal read = _G.GetWeaponEnchantInfo\n",
       "scrolls: the shim never used",
       expect="with GetWeaponEnchantInfo alone and a bare staff, you were offered", script=S)

# The list C_Item.GetWeaponEnchantInfo, every kind of enchant on the weapon:
# the scrolls' imbue is of the Imbue kind, which the old calls never report,
# so read without the list an imbue on was nothing on and asked for again.
mutate("Core.lua",
       "\t\tif type(list) == \"function\" then\n",
       "\t\tif false then\n",
       "scrolls: the imbue read without the list",
       expect="with Lesser Flame's imbue on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\tlocal entries = plain(list(slots and slots.MainHand or 0))\n",
       "\t\t\tlocal entries = plain(list(16))\n",
       "scrolls: the list asked for inventory slot 16",
       expect="with Lesser Flame's imbue on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\tlocal entries = plain(list(slots and slots.MainHand or 0))\n",
       "\t\t\tlocal entries = plain(list(slots and slots.MainHand or 16))\n",
       "scrolls: no main hand without the enum",
       expect="without the weapon enums and Lesser Flame on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\tlocal temporary, imbue = kinds and kinds.Temporary or 2, kinds and kinds.Imbue or 3\n",
       "\t\t\tlocal temporary, imbue = kinds and kinds.Temporary, kinds and kinds.Imbue\n",
       "scrolls: no Imbue kind without the enum",
       expect="without the weapon enums and Lesser Flame on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\t\telseif on == true and (kind == temporary or kind == imbue) then\n",
       "\t\t\t\telseif on == true and kind == temporary then\n",
       "scrolls: an imbue on the list not counted",
       expect="with Lesser Flame's imbue on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\t\telseif on == true and (kind == temporary or kind == imbue) then\n",
       "\t\t\t\telseif on == true and kind == imbue then\n",
       "scrolls: an oil on the list not counted",
       expect="with a wizard oil on the list, you were offered", script=S)

mutate("Core.lua",
       "\t\t\t\telseif on == true and (kind == temporary or kind == imbue) then\n",
       "\t\t\t\telseif on == true then\n",
       "scrolls: a permanent enchant counted",
       expect="with only Crusader on the staff, you were offered", script=S)

mutate("Core.lua",
       "\t\t\tif not has then\n\t\t\t\tif unknown then return nil end\n\t\t\t\treturn false\n",
       "\t\t\tif not has then\n\t\t\t\tif unknown then return nil end\n\t\t\t\treturn nil\n",
       "scrolls: an empty list read as no answer",
       expect="with the imbue worn off, you were offered", script=S)

# A secret, or a field missing, read as no enchant: the reminder asks for
# an imbue that may well be on.
mutate("Core.lua",
       "\t\t\t\tif unknown then return nil end\n",
       "",
       "scrolls: a withheld entry read as no enchant",
       expect="with hasEnchant secret, the weapon was read", script=S)

mutate("Core.lua",
       "\t\t\t\tif on == nil or (on == true and kind == nil) then\n",
       "\t\t\t\tif on == true and kind == nil then\n",
       "scrolls: a secret hasEnchant read as none",
       expect="with hasEnchant secret, the weapon was read", script=S)

mutate("Core.lua",
       "\t\t\t\tif on == nil or (on == true and kind == nil) then\n",
       "\t\t\t\tif on == nil then\n",
       "scrolls: a secret kind read as none",
       expect="with the enchant's kind secret, the weapon was read", script=S)

mutate("Core.lua",
       "\t\t\tif type(entries) ~= \"table\" then return nil end\n",
       "\t\t\tif type(entries) ~= \"table\" then return false end\n",
       "scrolls: a secret list read as empty",
       expect="with the whole list secret, the weapon was read", script=S)

# Which entry is read: the scroll's, beside an oil listed before or after it.
mutate("Core.lua",
       "\t\t\t\t\tif not has or (made and not named) then\n",
       "\t\t\t\t\tif not has then\n",
       "scrolls: an oil listed first read over the imbue",
       expect="an oil listed before two minutes of Lesser Flame: offered", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif not has or (made and not named) then\n",
       "\t\t\t\t\tif true then\n",
       "scrolls: an oil listed last read over the imbue",
       expect="an oil listed after two minutes of Lesser Flame: offered", script=S)

mutate("Core.lua",
       "\t\t\t\t\t\thas, enchant, expires, named = true, id, plain(info.timeLeft), made\n",
       "\t\t\t\t\t\thas, enchant, expires, named = true, id, nil, made\n",
       "scrolls: the list's time left never read",
       expect="two minutes of Lesser Flame on the list, top-ups on: offered", script=S)

mutate("Core.lua",
       "\t\t\t\t\t\thas, enchant, expires, named = true, id, plain(info.timeLeft), made\n",
       "\t\t\t\t\t\thas, enchant, expires, named = true, nil, plain(info.timeLeft), made\n",
       "scrolls: the imbue on the list never named",
       expect="with Lesser Flame's imbue on the staff, /manners debug says", script=S)

# An oil running low with top-ups on, taken for nothing to pick. Since the
# twin top-up (1.6.2) reads the scroll right after, the read throws.
mutate("Core.lua",
       "\t\t\tif not upSpell then return nil, true, left, \"up\" end\n",
       "",
       "scrolls: an oil running low said as nothing to pick",
       expect="an oil running low is an enchant on the weapon, not nothing to pick: threw", script=S)

# A scroll's cast cut short (Clicks.lua): the press kept, its block the
# whole retry cooldown.
mutate("Clicks.lua",
       "\tlocal stopped = ScrollCastStopped(plain(castGUID), plain(spellId), L[\"the cast was interrupted\"])\n",
       "\tlocal stopped = nil\n",
       "scrolls: an interrupted scroll kept as used",
       expect="2 s after the Rat Familiar's cast was interrupted, you were offered", script=S)

mutate("Clicks.lua",
       "\t\tlocal stopped = ScrollCastStopped(castGUID, nil, L[\"the game refused the cast\"])\n",
       "\t\tlocal stopped = nil\n",
       "scrolls: a scroll failing late kept as used",
       expect="2 s after the Rat Familiar's cast failed, you were offered", script=S)

mutate("Clicks.lua",
       "\t\tlocal stopped = ScrollCastStopped(castGUID, nil, L[\"the game refused the cast\"])\n",
       "\t\tlocal stopped = ScrollCastStopped(castGUID, spellId, L[\"the game refused the cast\"])\n",
       "scrolls: a failure naming no cast taken for the scroll's",
       expect="a failure naming no cast took back the Rat Familiar being cast", script=S)

mutate("Clicks.lua",
       "\tif castingScroll and ScrollCast(plain(castGUID), plain(spellId)) then castingScroll = nil end\n",
       "",
       "scrolls: a scroll that succeeded still undone",
       expect="a Rat Familiar cast that succeeded was taken back by a later interrupt", script=S)

mutate("Clicks.lua",
       "\tif GetTime() - cast.record.at > SCROLL_SECONDS then\n",
       "\tif false then\n",
       "scrolls: a scroll's cast held forever",
       expect="an interrupt 7 s after the Rat Familiar's three-second cast took the press back", script=S)

mutate("Clicks.lua",
       "\telseif spellId == nil or spellId ~= cast.spellId then\n",
       "\telse\n",
       "scrolls: an interrupt naming no cast never the scroll's",
       expect="with no cast guids, 2 s after the Rat Familiar's cast was interrupted, you were offered", script=S)

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
