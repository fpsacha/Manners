# Mutations for the cure button's modifiers and wording (Prompt/CureFight.lua,
# Cures.lua, Options/Look.lua, Options/Who.lua; GitHub issue 43). Each is
# caught by the scenario in tests/scenarios/curefight-mods.lua that names it.

S = "runscenarios.py"
CF = "Prompt/CureFight.lua"
LOOK = "Options/Look.lua"
P = "curefight-mods: "

mutate(CF,
       "\tif ctrlSpell then parts[#parts + 1] = Clause(ctrlSpell.name, \"ctrl\") end\n",
       "",
       P + "Ctrl casts nothing",
       expect=P + "a druid's three cures go plain, Shift and Ctrl", script=S)

mutate("Cures.lua",
       "\t\t\tif not found then\n\t\t\t\tlocal kinds = {}\n",
       "\t\t\tif false then\n\t\t\t\tlocal kinds = {}\n",
       P + "a third cure is never offered",
       expect=P + "a druid's three cures go plain, Shift and Ctrl", script=S)

mutate(CF,
       "\t\tif want ~= 0 then\n",
       "\t\tif true then\n",
       P + "Nothing on a modifier still casts its default",
       expect=P + "each modifier casts the cure picked for it, or nothing", script=S)

mutate(CF,
       "\t\t\t\t\tif spell.cure.ranks[1] == want then pick = spell break end\n",
       "",
       P + "a cure picked is never used",
       expect=P + "each modifier casts the cure picked for it, or nothing", script=S)

mutate(LOOK,
       "\t\tif value == Id(known[INDEX[mod]]) then\n\t\t\tmine[mod] = nil\n",
       "\t\tif false then\n\t\t\tmine[mod] = nil\n",
       P + "the default picked again is stored as a choice",
       expect=P + "each modifier casts the cure picked for it, or nothing", script=S)

mutate(LOOK,
       "\t\treturn not (known and known[2])\n",
       "\t\treturn false\n",
       P + "a single cure is offered modifier choices",
       expect=P + "a class with one cure has no modifier choices", script=S)

mutate(CF,
       "\tif slots[1].ctrlKey then ctrlSpell = nil end\n",
       "",
       P + "a key bound with Ctrl keeps the Ctrl clause",
       expect=P + "a key bound with Ctrl casts no Ctrl clause", script=S)

mutate(CF,
       "local key = keyLabel and (ctrl and L[\"Ctrl-%s\"]:format(keyLabel) or shift",
       "local key = keyLabel and (false and L[\"Ctrl-%s\"]:format(keyLabel) or shift",
       P + "the key line never names Ctrl",
       expect=P + "the key line names Ctrl for the Ctrl cure", script=S)

mutate(LOOK,
       "\t\t\t\tdesc = function() return L[\"Click, then press a key or a controller button. Esc cancels, a right-click clears it. Saved with your game key bindings, so it works on every profile.\"] .. CureMods.KeyLine() end,\n",
       "\t\t\t\tdesc = function() return L[\"Click, then press a key or a controller button. Esc cancels, a right-click clears it. Saved with your game key bindings, so it works on every profile.\"] end,\n",
       P + "the key's tooltip names no modifier",
       expect=P + "the key's tooltip names what Shift and Ctrl cast", script=S)

mutate(CF,
       "\treturn a ~= nil and b ~= nil and a ~= b\n",
       "\treturn a ~= nil\n",
       P + "a second button with nothing on Shift",
       expect=P + "A button for each cure keeps working with the modifiers", script=S)

mutate(CF,
       "\t\tArm(second, \"/cast \" .. Clause(shiftSpell.name, false))\n",
       "\t\tArm(second, \"/cast \" .. Clause((CureFight.Chosen(db)).name, false))\n",
       P + "the second button casts the plain cure",
       expect=P + "A button for each cure keeps working with the modifiers", script=S)

mutate("Options/Who.lua",
       "\t\ttype = \"description\",\n\t\tname = function()\n\t\t\treturn L[\"The cure button for a fight is set on its own page",
       "\t\ttype = \"toggle\",\n\t\tname = function()\n\t\t\treturn L[\"The cure button for a fight is set on its own page",
       P + "Who to buff draws the switch a second time",
       expect=P + "the switch is set in one place and Who to buff points at it", script=S)

mutate("Options/Window/WindowPage.lua",
       "\t[\"appearance.cureFightCtrl\"] = function() return CureModSaved(\"ctrl\") end,\n",
       "",
       P + "a choice is never marked",
       expect=P + "a choice is marked as changed and In a fight's reset puts it back", script=S)

mutate("Options/Advanced.lua",
       "\t\"prompt.cureFightMods\",\n",
       "",
       P + "In a fight's reset leaves the choice",
       expect=P + "a choice is marked as changed and In a fight's reset puts it back", script=S)

mutate(CF,
       "\t\t\t\tor EachCure(db) ~= placedEach or ChoiceKey(db) ~= placedChoice then\n",
       "\t\t\t\tor EachCure(db) ~= placedEach then\n",
       P + "a choice made is not armed until something else changes",
       expect=P + "each modifier casts the cure picked for it, or nothing", script=S)
