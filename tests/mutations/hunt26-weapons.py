# What goes on a weapon from the bags -- poisons, stones, oils, lures -- as your
# own buffs, per hand, and a rogue's poisons as spells (tests/scenarios/
# hunt26-weapons.lua): the items and families in Buffs.lua, the bags, the
# weapon in each hand and the enchants on it in Core.lua, the macro in
# Prompt/Macro.lua, the timed settle in Clicks.lua, the game's replace question
# (left to the player) in Core.lua, the rows (Options/Who.lua) and the debug
# lines (Commands.lua). Each fault put back has to be caught by the scenario
# that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
C = "Core.lua"
B = "Buffs.lua"
M = "Prompt/Macro.lua"

# ------------------------------------------------ the macro: which hand
# The off hand's enhancement aimed at the main hand.
mutate(M,
       "\tif entry.buff.enchant then lines[2] = \"/use \" .. slot end\n",
       "\tif entry.buff.enchant then lines[2] = \"/use 16\" end\n",
       "hunt26-weapons: the off hand aimed at the main hand",
       expect="hunt26-weapons: a rogue's poisons are offered one hand at a time", script=S)

# ------------------------------------------------ reading each hand
# The off hand's enchants read from the main hand's list (Forever's list).
mutate(C,
       "\t\tif family.slot == 17 then return slots and slots.OffHand or 1 end\n",
       "",
       "hunt26-weapons: the off hand's enchants read from the main hand's list",
       expect="hunt26-weapons: a rogue's poisons are offered one hand at a time", script=S)

# ...and the Classic clients' four values to a hand: the off hand's are the
# second four.
mutate(C,
       "\t\t\t\thas, expires, _, enchant = select(5, read())\n",
       "\t\t\t\thas, expires, _, enchant = read()\n",
       "hunt26-weapons: the off hand read from the main hand's four values",
       expect="hunt26-weapons: vanilla reads each hand with the global GetWeaponEnchantInfo", script=S)

# ------------------------------------------------ the weapon in the hand
# The mask of weapons an item fits never asked.
mutate(C,
       "\t\tif spell.fits and not Fits(spell.fits, hand) then return false, \"weapon\" end\n",
       "",
       "hunt26-weapons: any weapon takes any enhancement",
       expect="a mace with a stone and a weightstone in the bags was offered", script=S)

# The mask read as a number rather than a bit per weapon.
mutate(C,
       "\t\treturn type(subclass) == \"number\" and math.floor(mask / 2 ^ subclass) % 2 == 1\n",
       "\t\treturn type(subclass) == \"number\" and mask % 2 ^ subclass == 1\n",
       "hunt26-weapons: the mask of weapons misread",
       expect="a mace with a stone and a weightstone in the bags was offered", script=S)

# A shield, or a book held in the off hand, taken for a weapon of its subclass.
mutate(C,
       "\t\t\t\tif class == 2 and type(subclass) == \"number\" then held = subclass end\n",
       "\t\t\t\tif type(subclass) == \"number\" then held = subclass end\n",
       "hunt26-weapons: a shield taken for a weapon",
       expect="with the main hand poisoned and a shield in the off hand, you were offered", script=S)

# The level an item asks for, left out.
mutate(C,
       "\t\tif type(level) ~= \"number\" or level < spell.level then return false, \"level\" end\n",
       "",
       "hunt26-weapons: any level uses a stone",
       expect="a level-4 warrior with a Rough and a Coarse Weightstone was offered", script=S)

# ------------------------------------------------ the families and the classes
# A poison offered to every class.
mutate(B,
       "\t\t{ kind = \"poison\", label = L[\"Poison\"], only = \"ROGUE\" },\n",
       "\t\t{ kind = \"poison\", label = L[\"Poison\"] },\n",
       "hunt26-weapons: a poison offered to every class",
       expect="a mage has a poison family of her own", script=S)

# A lure for an off hand a pole cannot be in.
mutate(B,
       "\t\t{ kind = \"lure\", label = L[\"Fishing lure\"], mainHand = true },\n",
       "\t\t{ kind = \"lure\", label = L[\"Fishing lure\"] },\n",
       "hunt26-weapons: a lure for the off hand",
       expect="a lure has an off-hand family", script=S)

# Mists' elemental stone given Classic Era's mask: it fits a mace there.
mutate(B,
       "{ 18262, 50, 2506, 22756, ELEMENTAL_MISTS }",
       "{ 18262, 50, 2506, 22756, EITHER }",
       "hunt26-weapons: Mists' elemental stone fits a mace",
       expect="on Mists a mace was offered the elemental stone", script=S)

# A family known with nothing in the bags: every class shows every row.
mutate(C,
       "\t\t\treturn heldFirst[family]\n",
       "\t\t\treturn family.spells[1]\n",
       "hunt26-weapons: a family known with nothing in the bags",
       expect="the stone row is shown with no stone in the bags", script=S)

# The bags not read for the item a second family lists.
mutate(C,
       "\t\t\t\t\t\tlocal n = scrollCounts[scroll.item] or plain(count(scroll.item))\n",
       "\t\t\t\t\t\tlocal n = plain(count(scroll.item))\n",
       "hunt26-weapons: an item counted once for each hand",
       expect="the bags were read", script=S)

# ------------------------------------------------ a rogue's prompt
# Nothing to do for a rogue with a poison and nothing learned.
mutate(C,
       "\tif ns.OwnItemsHeld() then return true end\n",
       "",
       "hunt26-weapons: a rogue with a poison has nothing to cast",
       expect="a rogue with a poison in the bags can cast nothing", script=S)

mutate(C,
       "\treturn not caps.hasClassBuffs and (caps.anyOwnKnown == true or ns.OwnItemsHeld())\n",
       "\treturn not caps.hasClassBuffs and caps.anyOwnKnown == true\n",
       "hunt26-weapons: a rogue with a poison is not a class with buffs of its own",
       expect="a rogue with a poison in the bags is not a class with buffs of his own", script=S)

mutate(C,
       "\t\t\t\t\t\t\tanyHeld = true\n",
       "",
       "hunt26-weapons: the bags never said to hold an item",
       expect="a rogue with a poison in the bags can cast nothing", script=S)

# ------------------------------------------------ the names
mutate(C,
       "\t\tif family.enhance then return family.label .. \" (\" .. ns.HandName(family.slot) .. \")\" end\n",
       "\t\tif family.enhance then return family.label end\n",
       "hunt26-weapons: the hand left out of a family's name",
       expect="hunt26-weapons: a rogue's poisons are offered one hand at a time", script=S)

mutate(C,
       "\t\t\tinfo.name = called and (called .. info.hand) or nil\n",
       "\t\t\tinfo.name = called\n",
       "hunt26-weapons: the hand left out of an item's name",
       expect="the main hand's poison is named", script=S)

mutate(C,
       "\t\t\tinfo = ns.ProbeOwnItem(buff)\n",
       "",
       "hunt26-weapons: an enhancement never probed",
       expect="the main hand's poison is named", script=S)

# ------------------------------------------------ the settle: a hand busy for the cast
mutate(C,
       "\t\tif spell.family.enhance and ns.HandBusy(spell.family.slot, ctx.now) then\n",
       "\t\tif false then\n",
       "hunt26-weapons: a hand offered another enhancement during the cast",
       expect="with the stone being put on, the hand was offered", script=S)

mutate(C,
       "\t\tif spell.family.enhance then busyUntil[spell.family.slot] = GetTime() + HAND_BUSY end\n",
       "",
       "hunt26-weapons: a hand never busy",
       expect="with the stone being put on, the hand was offered", script=S)

mutate(C,
       "\t\tif spell.family.enhance then busyUntil[spell.family.slot] = nil end\n",
       "",
       "hunt26-weapons: a hand still busy after the cast was cut short",
       expect="2 s after the stone's cast was interrupted, you were offered", script=S)

# A lure's five seconds held to the scroll's six, and not held at all.
mutate("Clicks.lua",
       "\t\t\tseconds = own.family.enhance and ENHANCE_SECONDS or SCROLL_SECONDS }\n",
       "\t\t\tseconds = SCROLL_SECONDS }\n",
       "hunt26-weapons: an enhancement's cast held for a scroll's six seconds",
       expect="a lure interrupted 7 s after the press was not offered again", script=S)

mutate("Clicks.lua",
       "\t\t\tseconds = own.family.enhance and ENHANCE_SECONDS or SCROLL_SECONDS }\n",
       "\t\t\tseconds = 1e9 }\n",
       "hunt26-weapons: an enhancement's cast held for ever",
       expect="an interrupt 9 s after the lure's press took the press back", script=S)

# ------------------------------------------------ the replace question
# The game asks whether to replace the enchant on a weapon when an enhancement
# goes over it. The question is the player's: an automatic answer, or the
# popup taken down, is a fault. Each is put back as a handler for the event,
# registered with the others.
mutate(C,
       "\tfor _, event in ipairs({\n\t\t\"UNIT_AURA\",\n",
       "\tfunction addon:REPLACE_ENCHANT()\n"
       "\t\tif C_Item and C_Item.ReplaceEnchant then C_Item.ReplaceEnchant() end\n"
       "\tend\n"
       "\tfor _, event in ipairs({\n\t\t\"REPLACE_ENCHANT\",\n\t\t\"UNIT_AURA\",\n",
       "hunt26-weapons: the replace question answered for the player",
       expect="the game's question about replacing an enchant was answered", script=S)

mutate(C,
       "\tfor _, event in ipairs({\n\t\t\"UNIT_AURA\",\n",
       "\tfunction addon:REPLACE_ENCHANT()\n"
       "\t\tif StaticPopup_Hide then StaticPopup_Hide(\"REPLACE_ENCHANT\") end\n"
       "\tend\n"
       "\tfor _, event in ipairs({\n\t\t\"REPLACE_ENCHANT\",\n\t\t\"UNIT_AURA\",\n",
       "hunt26-weapons: the replace popup taken down",
       expect="the game's replace popup was taken down", script=S)

# ------------------------------------------------ the events
mutate(C,
       "\t\t\"WEAPON_ENCHANT_CHANGED\",\n",
       "",
       "hunt26-weapons: the enchant change not watched",
       expect="the enchant change is not watched", script=S)

mutate(C,
       "function addon:WEAPON_ENCHANT_CHANGED() ns.ownAurasChanged = true end\n",
       "function addon:WEAPON_ENCHANT_CHANGED() end\n",
       "hunt26-weapons: an enchant going on or off not noticed",
       expect="the enchant going on did not ask for a reading", script=S)

# ------------------------------------------------ a rogue's poisons as spells
mutate(B,
       "\tMISTS_OWN.ROGUE = { LETHAL, NONLETHAL }\n",
       "\tMISTS_OWN.ROGUE = {}\n",
       "hunt26-weapons: a Mists rogue has no poisons",
       expect="a Mists rogue with no poison up was offered", script=S)

mutate(B,
       "\town = MAINLINE_OWN,\n",
       "\town = {},\n",
       "hunt26-weapons: a retail rogue has no poisons",
       expect="a retail rogue who knows Instant Poison and Crippling Poison was offered", script=S)

# A lethal poison that is not in the family: Wound Poison up and Deadly offered.
mutate(B,
       "\t\t\t{ key = \"woundpoison\", ranks = { 8679 } },\n\t\t},\n\t}\n\tlocal NONLETHAL = {\n",
       "\t\t},\n\t}\n\tlocal NONLETHAL = {\n",
       "hunt26-weapons: Wound Poison not a lethal poison",
       expect="with Wound Poison up, a rogue was offered", script=S)

# ------------------------------------------------ the options page and /manners debug
mutate("Options/Who.lua",
       "\t\treturn ns.OwnSpellKnown(spell) or (type(picks) == \"table\" and picks[family.key] == spell.key)\n",
       "\t\treturn true\n",
       "hunt26-weapons: every item a choice",
       expect="a poison not in the bags is a choice", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\t\t:format(ns.HandName(family.slot))\n",
       "\t\t\t\t\t\t\t:format(ns.HandName(16))\n",
       "hunt26-weapons: the off hand's row names the main hand",
       expect="the off hand's row says", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"noweapon\" and family.enhance then\n",
       "\t\telseif false then\n",
       "hunt26-weapons: no weapon in an off hand said of the main hand",
       expect="/manners debug says, of a shield", script=S)

# ------------------------------------------------ the hand, read for an enhancement
# The weapon in the hand not asked for an enhancement: nothing fits nothing.
mutate(C,
       "\t\tlocal hand = (spell.weapon or spell.fits) and HandWeapon(spell.family and spell.family.slot or 16)\n",
       "\t\tlocal hand = spell.weapon and HandWeapon(spell.family and spell.family.slot or 16)\n",
       "hunt26-weapons: the weapon in the hand not read for an enhancement",
       expect="a level-60 rogue with Instant Poison VI in the bags and bare daggers was offered", script=S)

# The off hand's enhancement judged by the main hand's weapon.
mutate(C,
       "\t\tlocal hand = (spell.weapon or spell.fits) and HandWeapon(spell.family and spell.family.slot or 16)\n",
       "\t\tlocal hand = (spell.weapon or spell.fits) and HandWeapon(16)\n",
       "hunt26-weapons: the off hand judged by the main hand's weapon",
       expect="with the main hand poisoned and a shield in the off hand, you were offered", script=S)

# The off hand named the main hand.
mutate(C,
       "\t\tif slot == 17 then return _G.INVTYPE_WEAPONOFFHAND or \"Off Hand\" end\n",
       "\t\tif slot == 17 then return _G.INVTYPE_WEAPONOFFHAND or \"Main Hand\" end\n",
       "hunt26-weapons: the off hand called the main hand",
       expect="hunt26-weapons: a rogue's poisons are offered one hand at a time", script=S)

# ------------------------------------------------ naming, probing
# Every item of a class asked about at the probe.
mutate(C,
       "\t\t\tfor _, spell in ipairs(family.enhance and {} or family.spells) do\n",
       "\t\t\tfor _, spell in ipairs(family.spells) do\n",
       "hunt26-weapons: every item probed at login",
       expect="the probe asked the client for the names of", script=S)

# The item's name never taken once the client has loaded it.
mutate(C,
       "\tif info and info.itemPending then ns.ResolveItemName(info) end\n",
       "",
       "hunt26-weapons: an item's name never taken once loaded",
       expect="once the item loaded, Crippling Poison II reads", script=S)

# The hand left off a name the item does not yet have.
mutate(C,
       "\t\tif enhance then info.hand = \" (\" .. ns.HandName(spell.family.slot) .. \")\" end\n",
       "\t\tif enhance then info.hand = \"\" end\n",
       "hunt26-weapons: the hand left off an unloaded item's name",
       expect="before the item loaded, Crippling Poison II reads", script=S)

# ------------------------------------------------ Automatic
# The poison on the hand never written down for Automatic.
mutate(C,
       "\t\tif scroll then Remember(family, scroll) end\n",
       "",
       "hunt26-weapons: the poison on the hand never remembered",
       expect="with Deadly Poison V the last on the main hand, you were offered", script=S)

# ------------------------------------------------ the options window
# A family with no place in the window.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_lure\", indent = true },\n",
       "",
       "hunt26-weapons: the lure row has no place in the window",
       expect="who.own_lure (select", script=S)

# ------------------------------------------------ the in-game selftest
# A stone taken for a scroll by the report.
mutate("Selftest.lua",
       "local function HasScrolls() return OwnFamily(function(f) return f.scroll and not f.enhance end) ~= nil end\n",
       "local function HasScrolls() return OwnFamily(function(f) return f.scroll end) ~= nil end\n",
       "hunt26-weapons: the selftest takes a stone for a scroll",
       expect="a warrior holding a stone is reported as", script=S)
