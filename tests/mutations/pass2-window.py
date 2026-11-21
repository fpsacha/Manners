# Mutations for pass 2, the window lens: tests/scenarios/pass2-window.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back one of the
# faults the pass found and names the scenario that objects.

S = "runscenarios.py"
P = "pass2-window: "
FIGHTKEY = "Prompt/FightKey.lua"
ADV = "Options/Advanced.lua"
LOOK = "Options/Look.lua"
WIDGETS = "Options/Window/Widgets.lua"

# --- the words ---------------------------------------------------------------

mutate("Locales/deDE.lua", 'L["Cure myself too"] = "Auch mich selbst reinigen"',
       'L["Cure myself too"] = "Auch mich selbst entfernen"',
       "pass2-window: the German cure switch says remove",
       expect=P + "the German Cure myself too", script=S)

mutate("Locales/frFR.lua", 'L["Fire Ward or Frost Ward"] = "Gardien de feu ou Gardien de givre"',
       'L["Fire Ward or Frost Ward"] = "Protection contre le feu ou Protection contre le givre"',
       "pass2-window: the French ward row not the client's names",
       expect=P + "Fire Ward and Frost Ward carry the client's names in frFR", script=S)

mutate("Locales/frFR.lua", "Bouclier de mana, Gardien de feu et Gardien de givre ne sont",
       "Bouclier de mana, Protection contre le feu et Protection contre le givre ne sont",
       "pass2-window: the French ward note not the client's names",
       expect=P + "Fire Ward and Frost Ward carry the client's names in frFR", script=S)

mutate("Locales/koKR.lua", 'L["Fire Ward or Frost Ward"] = "화염계 수호 또는 냉기계 수호"',
       'L["Fire Ward or Frost Ward"] = "화염 수호물 또는 냉기 수호물"',
       "pass2-window: the Korean ward row not the client's names",
       expect=P + "Fire Ward and Frost Ward carry the client's names in koKR", script=S)

mutate("Locales/koKR.lua", "마나 보호막, 화염계 수호, 냉기계 수호는",
       "마나 보호막, 화염 수호물, 냉기 수호물은",
       "pass2-window: the Korean ward note not the client's names",
       expect=P + "Fire Ward and Frost Ward carry the client's names in koKR", script=S)

# --- In a fight, my key casts, per class -----------------------------------------

mutate(FIGHTKEY, 'return type(by) == "table" and class and by[class] or nil',
       'return type(by) == "table" and class and (by[class] or select(2, next(by))) or nil',
       "pass2-window: another class's fight key lent to this one",
       expect=P + "a fight key chosen on a priest does not arm a paladin", script=S)

mutate("Core.lua", "if #classes == 1 then\n\t\t\t\ttarget = classes[1]",
       "if #classes >= 1 then\n\t\t\t\ttarget = classes[1]",
       "pass2-window: a key two classes share given to one of them",
       expect=P + "an old shared fight key", script=S)

mutate("Core.lua", "if c == mine then target = mine end",
       "if false then target = mine end",
       "pass2-window: a key two classes share dropped for the class logging in",
       expect=P + "an old shared fight key", script=S)

mutate("Commands.lua", 'name == "prompt.classStyles" or name == "prompt.fightKeySpells" then',
       'name == "prompt.classStyles" then',
       "pass2-window: the fight key left out of a settings string",
       expect=P + "the fight key travels in a settings string", script=S)

mutate("Core.lua", '\t\tp.fightKeySpell = nil\n\t\tif type(old) == "string"',
       '\t\tif type(old) == "string"',
       "pass2-window: the old fight key field kept",
       expect=P + "an old shared fight key", script=S)

mutate(ADV, '"prompt.fightKeySpells", "prompt.fightKeyOn",',
       '"prompt.fightKeyOn",',
       "pass2-window: In a fight's reset leaves the fight keys",
       expect="advanced: put these back to default on In a fight", script=S)

# --- the short-buff hold beside Never in cities and inns -----------------------------

mutate("Options/Who.lua", "disabled = function() return F().quietShortInTowns ~= true end,",
       "disabled = function() return F().quietShortInTowns ~= true or F().quietInTowns == true end,",
       "pass2-window: the short-buff minutes greyed while the rule acts on you",
       expect=P + "the short-buff hold stays live", script=S)

# --- own words ---------------------------------------------------------------

mutate("Ask.lua", "\t\t\tif #text - i + 1 < need then text = text:sub(1, i - 1) end\n",
       "",
       "pass2-window: own words cut in the middle of a character",
       expect=P + "own words cut to fit end on a whole character", script=S)

# --- Who to buff's reset -----------------------------------------------------

mutate(ADV, '"filters.cureSeconds", "prompt.cureFight",',
       '"filters.cureSeconds",',
       "pass2-window: Who's reset leaves the cure in a fight",
       expect=P + "Who to buff's reset puts back the fight switches", script=S)

mutate(ADV, '"beast.bond", "beast.fightMend",\n',
       '"beast.bond",\n',
       "pass2-window: Who's reset leaves Mend Pet in a fight",
       expect=P + "Who to buff's reset puts back the fight switches", script=S)

# --- the cure in a fight needs a cure -------------------------------------------

mutate("Cures.lua", "\treturn ns.CureFightSpells() ~= nil\n",
       "\treturn true\n",
       "pass2-window: a cure switch offered with none learned",
       expect=P + "the cure's switch on Who to buff", script=S)

mutate(LOOK, "\t\t\t\t\t\tlocal spell = list and list[1] and list[1].name\n",
       '\t\t\t\t\t\tlocal spell = list and list[1] and list[1].name or ""\n',
       "pass2-window: the cure's key line names no spell",
       expect=P + "the cure key's line never names an empty spell", script=S)

mutate("Options/Who.lua", "hidden = function() return NoCures() or not ns.CureLearned() end,",
       "hidden = NoCures,",
       "pass2-window: Who's cure switch offered with none learned",
       expect=P + "the cure's switch on Who to buff", script=S)

mutate(LOOK, "hidden = function() return not (ns.ClassHasCures() and ns.CureLearned()) end,",
       "hidden = function() return not ns.ClassHasCures() end,",
       "pass2-window: Look's cure switch offered with none learned",
       expect=P + "the cure's switch on Who to buff", script=S)

mutate(LOOK, 'if not spell then return "" end',
       'if not spell then return L["%s was bound to %s; it now buffs the prompted player."]:format(key, was) end',
       "pass2-window: the cure key's line says it buffs the prompted player",
       expect=P + "the cure key's line never names an empty spell", script=S)

# --- the page bar --------------------------------------------------------------

mutate(WIDGETS, "if (range ~= grab.range or travel ~= grab.travel) and travel > 0 and",
       "if false and travel > 0 and",
       "pass2-window: a drag keeps the travel of the press",
       expect=P + "the page bar's thumb stays under the cursor", script=S)
