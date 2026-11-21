# Mutations for the prompt's own key in a fight (Prompt/FightKey.lua, the two
# calls in Core.lua's pull and release, and the place its controls have in
# Options/Window/Layout.lua). Caught by tests/scenarios/fightkey.lua; each
# undoes one rule.

S = "runscenarios.py"
FK = "Prompt/FightKey.lua"

mutate(FK,
       "function FightKey:Take()\n\tif InCombatLockdown() then return end\n",
       "function FightKey:Take()\n",
       "fightkey: Take touches the bindings under the lockdown",
       expect="fightkey: no binding is touched under the lockdown", script=S)

mutate(FK,
       "\tif owner then _G.ClearOverrideBindings(owner) end\n\ttaken = nil\nend\n\n-- From a scan",
       "\ttaken = nil\nend\n\n-- From a scan",
       "fightkey: the end of the fight leaves the key where it was lent",
       expect="fightkey: out of a fight the key buffs again", script=S)

mutate("Core.lua",
       "\tif ns.FightKey then ns.Guard(\"fight key\", ns.FightKey.Take, ns.FightKey) end\n",
       "",
       "fightkey: the pull never takes the key",
       expect="fightkey: a priest's key casts Power Word: Shield", script=S)

mutate(FK,
       "\t\tif on == \"me\" then\n",
       "\t\tif false then\n",
       "fightkey: the macro ignores who it lands on",
       expect="fightkey: the macro is the conditional one off Forever and a bare cast on Forever", script=S)

mutate(FK,
       "\telse\n\t\tmacro = \"/cast \" .. row.name\n\tend\n\tif #macro",
       "\telse\n\t\tmacro = \"/cast [@mouseover,help,nodead][help,nodead][@player] \" .. row.name\n\tend\n\tif #macro",
       "fightkey: Forever gets a conditional it cannot resolve",
       expect="fightkey: the macro is the conditional one off Forever and a bare cast on Forever", script=S)

mutate(FK,
       "\t\t\tif ns.SpellKnown(row.id) then\n\t\t\t\tlocal name",
       "\t\t\tif true then\n\t\t\t\tlocal name",
       "fightkey: the list offers spells not known",
       expect="fightkey: the list offers only spells the character knows", script=S)

mutate(FK,
       "\tbutton:SetScript(\"PreClick\", PreClick)\n\tbutton:Hide()\n",
       "\tbutton:SetScript(\"PreClick\", PreClick)\n\tbutton:Hide()\n\tbutton:Show()\n",
       "fightkey: the button is shown",
       expect="fightkey: nothing new is shown in a fight", script=S)

mutate(FK,
       "\treturn State().byKey[key]\n",
       "\tfor _, row in ipairs(Rows() or {}) do\n"
       "\t\tif row.key == key then return { key = row.key, id = row.id, self = row.self, name = ns.SpellNameFor(row.id) } end\n"
       "\tend\n"
       "\treturn nil\n",
       "fightkey: a chosen spell is kept after it is forgotten",
       expect="fightkey: a spell no longer known gives the key back to the prompt", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"appearance.fightKeySpell\",\n\t\t\t\t\t{ \"appearance.fightKeyOn\", indent = true },\n",
       "",
       "fightkey: the controls are not placed",
       expect="fightkey: the controls sit under In a fight after the rota", script=S)

mutate(FK,
       "function FightKey:Refresh()\n\tif InCombatLockdown() then return end\n",
       "function FightKey:Refresh()\n",
       "fightkey: a change in a fight is written at once",
       expect="fightkey: a change in a fight counts from the next one", script=S)
