# The ids checked against the online databases (Wowhead Forever, the Forever
# guides) and the client's own tables: each fix put back, and required to be
# caught by its scenario in tests/scenarios/ids-online.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ Reagent Economy
mutate("GroupBuffs.lua",
       "\treturn UsableAnswer(info.groupRank) == true\n",
       "\treturn false\n",
       "ids-online: the perk never read",
       expect="ids-online: Reagent Economy offers the group spell with no reagent (mage)", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif waived or (have and have > 0 and Usable(info.groupRank)) then\n",
       "\t\t\tif have and have > 0 and Usable(info.groupRank) then\n",
       "ids-online: a waived reagent still asked for in the bags",
       expect="with Reagent Economy and no Symbol of Kings was not offered", script=S)
mutate("GroupBuffs.lua",
       "\tif (ns.Flavour and ns.Flavour.flavour) ~= \"camelot\" then return false end\n",
       "",
       "ids-online: the perk read on every client",
       expect="Classic Era offered Arcane Brilliance with no Arcane Powder", script=S)
mutate("GroupBuffs.lua",
       "\treturn UsableAnswer(info.groupRank) == true\n",
       "\treturn UsableAnswer(info.groupRank) ~= false\n",
       "ids-online: a client that says nothing taken as the perk",
       expect="ids-online: without Reagent Economy an empty bag is no group cast (the client says nothing)",
       script=S)
mutate("GroupBuffs.lua",
       "\tif have ~= 0 or not (info and info.groupRank) then return false end\n",
       "\tif have == nil or not (info and info.groupRank) then return false end\n",
       "ids-online: a stocked bag read as the perk",
       expect="with no perk the reagent reads as waived while the bags hold it", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif not waived then NoteStock(info, have, db) end\n",
       "\t\t\tNoteStock(info, have, db)\n",
       "ids-online: the perk's empty bag said as running out",
       expect="was told the prompt goes back to one at a time", script=S)
mutate("GroupBuffs.lua",
       "\t\treagentWaived = bucket.ready.waived or nil,\n",
       "",
       "ids-online: the group cast forgets the waiver",
       expect="the tooltip counts a reagent the cast does not use", script=S)
mutate("Prompt/Button.lua",
       "\tif group.reagentWaived then\n",
       "\tif false then\n",
       "ids-online: the tooltip counts a waived reagent",
       expect="the tooltip counts a reagent the cast does not use", script=S)
mutate("Options/Who.lua",
       "\t\t\t\telseif ns.ReagentWaived and ns.ReagentWaived(info, count) then\n",
       "\t\t\t\telseif false then\n",
       "ids-online: Who to buff says group buffs are off for want of a waived reagent",
       expect="Who to buff tells a mage with Reagent Economy group buffs are off", script=S)
mutate("Options/Start.lua",
       "\t\t\t\tif count == 0 and ns.ReagentWaived and ns.ReagentWaived(info, 0) then count = nil end\n",
       "",
       "ids-online: Start here says group buffs are off for want of a waived reagent",
       expect="Start here tells a mage with Reagent Economy group buffs are off", script=S)
mutate("Options/Diagnostics.lua",
       "\t\t\t\twaived and \" (waived: the client says it is usable without)\" or \"\")\n",
       "\t\t\t\t\"\")\n",
       "ids-online: the bug report silent on the waiver",
       expect="the bug report does not say the reagent is waived", script=S)

# ------------------------------------------------ Spellbreak in the client's words
for code, ours, old in (
        ("deDE", "Zauberbrechen erfüllen", "Zauberbruch verleihen"),
        ("ptBR", "Imbuir Rompencanto", "Imbuir Quebra-feitiço"),
        ("koKR", "주문 파괴 주입", "주문파괴 부여"),
        ("zhCN", "注入破法", "破法灌注"),
        ("zhTW", "灌注斷法", "破法灌注"),
        ("esES", "Imbuir rompehechizos", "Imbuir Rompehechizos")):
    mutate("Locales/%s.lua" % code,
           "L[\"Imbue Spellbreak\"] = \"%s\"\n" % ours,
           "L[\"Imbue Spellbreak\"] = \"%s\"\n" % old,
           "ids-online: Spellbreak's old %s name" % code,
           expect="ids-online: Spellbreak's stand-in name is the client's in %s" % code, script=S)

# ------------------------------------------------ Buffs.lua's notes
mutate("Buffs.lua",
       "learned at 16 (Wowhead retail; retail SpellLevels 16).",
       "learned at 17.",
       "ids-online: Skyfury learned at 17",
       expect="Buffs.lua does not say Skyfury is learned at 16", script=S)
mutate("Buffs.lua",
       "\t-- The use is aimed at an item (Targets 16), as an oil's is: the macro hands\n"
       "\t-- it the main-hand weapon with /use 16 (Prompt/Macro.lua). It lasts an hour.\n",
       "\t-- The use enchants the weapon in the main hand by itself, for an hour.\n",
       "ids-online: the imbue said to need no target",
       expect="Buffs.lua says a scroll imbue enchants the weapon by itself", script=S)
mutate("Buffs.lua",
       "-- Forever's own: scrolls a mage finds -- in a Bundle of Scrolls from Study,\n"
       "-- or by deciphering an untranslated scroll with Comprehend Scroll (both\n"
       "-- Comprehension spells) -- and reads from the bags, a familiar and a weapon\n"
       "-- imbue.",
       "-- Forever's own: scrolls a mage writes with Comprehension and reads from the\n"
       "-- bags, a familiar and a weapon imbue.",
       "ids-online: the scrolls said to be written",
       expect="Buffs.lua says a mage writes the scrolls", script=S)
