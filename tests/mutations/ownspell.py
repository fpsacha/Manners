# Mutations for a mage's Mana Shield, Fire Ward and Frost Ward (Buffs.lua) and
# for Add a spell of my own (OwnSpells.lua; asked for on CurseForge). Caught by
# tests/scenarios/ownspell.lua.

S = "runscenarios.py"

# The shields.
mutate("Buffs.lua",
       "\t\t{ key = \"manashield\", optIn = true, brief = true,",
       "\t\t{ key = \"manashield\", brief = true,",
       "ownspell: Mana Shield on for every mage",
       expect="ownspell: shields: off on a new profile", script=S)

mutate("Buffs.lua",
       "ranks = { 27131, 10193",
       "ranks = { 10193",
       "ownspell: Burning Crusade's Mana Shield rank forgotten",
       expect="ownspell: shields: Mana Shield and a ward for a mage", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"frostward\", ranks = { 28609, 10177, 8462, 8461, 6143 } },\n",
       "",
       "ownspell: Frost Ward missing from the family",
       expect="ownspell: shields: Mana Shield and a ward for a mage", script=S)

mutate("Buffs.lua",
       "\t\t{ 60, 10193, 10192, 10191, 8495, 8494, 1463 }, -- Mana Shield (1 min)",
       "\t\t-- gone",
       "ownspell: Mana Shield has no length",
       expect="ownspell: shields: Mana Shield and a ward for a mage", script=S)

mutate("Modules/MyBuffs/Options.lua",
       "if family.brief then return L[\"Reminds you when no ward",
       "if false then return L[\"Reminds you when no ward",
       "ownspell: the ward's text says nothing of a fight",
       expect="ownspell: shields: the page says outside a fight", script=S)

mutate("Modules/MyBuffs/Options.lua",
       "or family.brief\n\t\t\t\t\tand L[\"Reminds you when it is not on you, outside",
       "or false\n\t\t\t\t\tand L[\"Reminds you when it is not on you, outside",
       "ownspell: Mana Shield's text says nothing of a fight",
       expect="ownspell: shields: the page says outside a fight", script=S)

mutate("Modules/MyBuffs/Layout.lua",
       "\t\t\t\t\t{ \"who.own_ward\", indent = true },\n",
       "",
       "ownspell: the ward not placed after Mana Shield",
       expect="ownspell: shields: the page says outside a fight", script=S)

# The page.
mutate("Modules/MyBuffs/Options.lua",
       "\t\t\tif family.custom then break end\n",
       "",
       "ownspell: an added spell gets a control of its own",
       expect="ownspell: no control of its own on the page", script=S)

mutate("Modules/MyBuffs/Options.lua",
       "\tAddOwnSpellControls(args)\n",
       "",
       "ownspell: the section is not built",
       expect="ownspell: a class with nothing for others sees the section", script=S)

# The checks on what is typed.
mutate("Modules/MyBuffs/OwnSpells.lua",
       "if not ns.SpellKnown(id) then return Answer(",
       "if false then return Answer(",
       "ownspell: a spell not in the spellbook is added",
       expect="ownspell: a spell this character does not know is refused", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if ns.safecall(C_Spell and C_Spell.IsSpellPassive, id) == true then",
       "if false then",
       "ownspell: a passive spell is added",
       expect="ownspell: a passive spell is refused", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if ns.safecall(C_Spell and C_Spell.IsSpellHarmful, id) == true then",
       "if false then",
       "ownspell: a harmful spell is added",
       expect="ownspell: a spell cast on an enemy is refused", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if ns.BUFF_BY_ID[id] then return",
       "if false then return",
       "ownspell: a buff for others is added by its id",
       expect="ownspell: a spell Manners covers is refused", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if own[key] then return",
       "if false then return",
       "ownspell: an own buff is added by its name",
       expect="ownspell: a spell Manners covers is refused", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "OS.MAX = 10",
       "OS.MAX = 11",
       "ownspell: eleven allowed",
       expect="ownspell: ten at most", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if entry.id == id or (entry.name and entry.name:lower() == lower) then return Answer(TEXT.TWICE",
       "if false then return Answer(TEXT.TWICE",
       "ownspell: the same spell added twice",
       expect="ownspell: the same spell twice is refused", script=S)

# Behaving as an own buff.
mutate("Modules/MyBuffs/OwnSpells.lua",
       "list[#list + 1] = { key = key, custom = true,",
       "local _ = { key = key, custom = true,",
       "ownspell: the entries never become families",
       expect="ownspell: added by name", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "ns.Guard(\"own spells\", Sync)",
       "local _ = Sync",
       "ownspell: the list is never synced before a probe",
       expect="ownspell: added by name", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if not Covered(entry.id, name, own, buffs) then",
       "if true then",
       "ownspell: a spell Manners came to cover is made twice",
       expect="ownspell: one Manners came to cover is left to Manners", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "local entry = table.remove(list, index)",
       "local entry = list[index]",
       "ownspell: Remove leaves it on the list",
       expect="ownspell: Remove takes it off", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "and not seenIds[e.id] and #out < OS.MAX then",
       "then",
       "ownspell: repair lets an id twice and eleven through",
       expect="ownspell: a damaged list is repaired", script=S)

mutate("Core.lua",
       "if ns.OwnSpells then ns.OwnSpells.Repair(addon.db.char) end",
       "-- no repair",
       "ownspell: ClampSettings does not repair the list",
       expect="ownspell: a damaged list is repaired", script=S)

# The verdict.
mutate("Modules/MyBuffs/OwnSpells.lua",
       "table.remove(Entries(), IndexOf(entry))",
       "local _ = IndexOf(entry)",
       "ownspell: a spell that left no aura stays",
       expect="ownspell: a spell that leaves no aura", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if InCombatLockdown() or not IndexOf(entry) then return end",
       "if not IndexOf(entry) then return end",
       "ownspell: judged when a fight has begun",
       expect="ownspell: no verdict in a fight", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if up == nil then return end",
       "if up == nil then up = false end",
       "ownspell: judged on a withheld read",
       expect="ownspell: no verdict in a fight", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "\t\tif me == false and not (target == ns.plain(UnitName(\"pet\")) and CannotTargetMe(id)) then return end\n",
       "",
       "ownspell: judged after a cast on somebody else",
       expect="ownspell: cast on somebody else, no verdict", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "\t\tif me == nil and friend and ns.safecall(C_Spell and C_Spell.IsSpellHelpful, id) == true then return end\n",
       "",
       "ownspell: a helpful spell cast at nobody is judged",
       expect="ownspell: cast on somebody else, no verdict", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if not entry.seen then",
       "if true then",
       "ownspell: an entry seen once is judged again",
       expect="ownspell: no verdict in a fight", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if InCombatLockdown() then return Answer(TEXT.IN_FIGHT) end",
       "if false then return Answer(TEXT.IN_FIGHT) end",
       "ownspell: added in a fight",
       expect="ownspell: not in a fight", script=S)

mutate("Commands.lua",
       "\telseif input == \"spell\" then\n\t\tif ns.OwnSpells then ns.OwnSpells.Slash(rest) end\n",
       "",
       "ownspell: /manners spell does nothing",
       expect="ownspell: /manners spell adds, lists and removes", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "local char = type(db) == \"table\" and db.char or nil",
       "local char = type(db) == \"table\" and db.profile or nil",
       "ownspell: kept in the profile",
       expect="ownspell: kept per character", script=S)

# A spell on a cooldown of its own is not offered.
mutate("Core.lua",
       "					and start + duration > GetTime() then\n					return false\n",
       "					and start + duration > GetTime() then\n					return true\n",
       "ownspell: offered during its cooldown",
       expect="ownspell: cooldown:", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "if me == nil and friend and ns.safecall",
       "if me == nil and ns.safecall",
       "ownspell: a cast naming nobody with no friend targeted is never judged",
       expect="ownspell: a spell cast at nobody with nobody targeted is judged", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "and (type(range) ~= \"function\" or ns.plain(range(id, \"target\")) ~= nil) or nil",
       "or nil",
       "ownspell: a spell with no range held for the friend targeted",
       expect="ownspell: a spell cast at nobody with nobody targeted is judged", script=S)
