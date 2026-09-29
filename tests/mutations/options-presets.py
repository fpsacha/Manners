# The helpers Start here is built on: the quick choices (ns.QuickSetup), the
# summaries, and the key and macro helpers (ns.Setup). Each fault is caught by
# the scenario in tests/scenarios/options-presets.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- matching a preset ---

# Every field treated as matching: the first preset always shows.
mutate("Options.lua",
       "\t\tif not loose[path] and not Quick.Ignored(list, path) and Quick.Get(path) ~= value then return false end\n",
       "\t\tif false then return false end\n",
       "presets: every preset matches",
       expect="a new profile matches", script=S)

# Fine-tuning a choice counted as leaving it.
mutate("Options.lua",
       "\t\tif not loose[path] and not Quick.Ignored(list, path) and Quick.Get(path) ~= value then return false end\n",
       "\t\tif not Quick.Ignored(list, path) and Quick.Get(path) ~= value then return false end\n",
       "presets: fine-tuning shows Custom",
       expect="a passer-by distance changed by hand shows", script=S)

mutate("Options.lua",
       "\t}, applyOnly = { [\"speech.onlyWhenReturning\"] = true } },\n\t{ key = \"whisper\"",
       "\t} },\n\t{ key = \"whisper\"",
       "presets: speaking first leaves A polite line",
       expect="speaking to people buffed first shows", script=S)

# A Who choice writing the group settings again, as the raid one did.
mutate("Options.lua",
       "\t\t[\"filters.whenBuffed\"] = \"refresh\",\n\t}, applyOnly",
       "\t\t[\"filters.whenBuffed\"] = \"refresh\", [\"groupBuffs.use\"] = true,\n\t}, applyOnly",
       "presets: raid turns group buffs back on",
       expect="switched group buffs or a priority back on", script=S)

# Lines edited by hand still counted as the set.
mutate("Options.lua",
       "\t\treturn sp.phrases == ns.PhraseSetText(entry.lines)\n",
       "\t\treturn true\n",
       "presets: edited lines still match their set",
       expect="edited lines still show", script=S)

# A warrior's passer-by switch held against the other choices.
mutate("Options.lua",
       "\treturn list == Quick.WHO and ns.OnlyReachesGroup()\n",
       "\treturn false and ns.OnlyReachesGroup()\n",
       "presets: a warrior's passers-by are compared",
       expect="rather than People who buff me, and my group", script=S)

# Everyone near me offered to a shout.
mutate("Options.lua",
       "\treturn not (list == Quick.WHO and entry.key == \"nearby\" and ns.OnlyReachesGroup())\n",
       "\treturn true\n",
       "presets: a warrior is offered passers-by",
       expect="is offered Everyone near me", script=S)

# --- the dropdown ---

# Custom offered whatever matches.
mutate("Options.lua",
       "\tif Quick.Match(list) == \"custom\" then out.custom = L[\"Custom (changed by hand)\"] end\n",
       "\tout.custom = L[\"Custom (changed by hand)\"]\n",
       "presets: Custom always offered",
       expect="Custom is offered on a profile nobody has touched", script=S)

# Custom left out of the order, so it sorts wherever its label falls.
mutate("Options.lua",
       "\tif values.custom then keys[#keys + 1] = \"custom\" end\n",
       "",
       "presets: Custom not last",
       expect="Custom is not last in the dropdown", script=S)

# --- applying one ---

# The set's lines not loaded.
mutate("Options.lua",
       "\t\t\t\tsp.phrases = ns.PhraseSetText(entry.lines) or sp.phrases\n",
       "",
       "presets: lines not loaded",
       expect="did not load the", script=S)

# Picking anything, Custom included, applies the first preset.
mutate("Options.lua",
       "\t\tif entry.key == key then return entry end\n",
       "\t\treturn list[1]\n",
       "presets: Custom applies a preset",
       expect="picking Custom changed something", script=S)

# Nothing said about it.
mutate("Options.lua",
       "\t\t\tns.addon:Print(L[\"Set up: %s.\"]:format(entry.name))\n",
       "",
       "presets: applied silently",
       expect="said nothing in chat", script=S)

# A preset reaching past what it is about.
mutate("Options.lua",
       "\t{ key = \"favours\", name = L[\"Only people who buff me\"], set = {\n",
       "\t{ key = \"favours\", name = L[\"Only people who buff me\"], set = {\n"
       "\t\t[\"sources.asked\"] = false,\n",
       "presets: a preset switches chat requests off",
       expect="switched off People who ask me in chat", script=S)

# The button written in combat instead of waiting for the fight to end.
mutate("Options.lua",
       "\t\t\t-- The hooks the individual setters run; both hold off in combat.\n"
       "\t\t\tns.Prompt:InvalidateMacro()\n",
       "\t\t\t-- The hooks the individual setters run; both hold off in combat.\n"
       "\t\t\tns.Prompt:GetButton():SetAttribute(\"macrotext1\", \"/say hi\")\n",
       "presets: the button written in combat",
       expect="a preset in combat called", script=S)

# --- asking first ---

mutate("Options.lua",
       "\t\tif Quick.Match(list) == \"custom\" then\n",
       "\t\tif true then\n",
       "presets: moving between presets asks",
       expect="moving from one preset to another asks first", script=S)

mutate("Options.lua",
       "\t\tif edited and not inCharacter then\n",
       "\t\tif not inCharacter then\n",
       "presets: unedited lines ask before loading",
       expect="loading the lines over unedited lines asks first", script=S)

mutate("Options.lua",
       "\tif entry.lines then\n\t\tlocal sp = SP()\n\t\tlocal edited",
       "\tif true then\n\t\tlocal sp = SP()\n\t\tlocal edited",
       "presets: a choice without lines asks about them",
       expect="a choice that loads no lines asks about replacing them", script=S)

# --- the summaries ---

mutate("Options.lua",
       "\tif s.asked then text = text .. \" \" .. L[\"People who ask in chat: on.\"] end\n",
       "",
       "presets: the summary leaves out chat requests",
       expect="the summary does not say chat requests are on", script=S)

mutate("Options.lua",
       "\tif s.strangers and not ns.OnlyReachesGroup() then\n",
       "\tif s.strangers then\n",
       "presets: the summary promises a warrior passers-by",
       expect="the summary promises a warrior passers-by", script=S)

mutate("Options.lua",
       "\telseif set and sp.phrases == ns.PhraseSetText(sp.presetChoice or \"roleplay\") then\n",
       "\telseif set then\n",
       "presets: lines written by hand described as a set",
       expect="lines written by hand are described as a set", script=S)

# The dropdown's label dropped into the sentence again.
mutate("Options.lua",
       "\t\tphrase = set.summary\n",
       "\t\tphrase = set.label\n",
       "presets: the set's label in the sentence",
       expect="presets: every line set reads as English in the summary", script=S)

# Favours only still told what happens to people already buffed.
mutate("Options.lua",
       "\tif s.owed and not (s.group or s.asked or (s.strangers and not ns.OnlyReachesGroup())) then\n",
       "\tif false then\n",
       "presets: favours only told about already buffed",
       expect="favours only reads", script=S)

mutate("Options.lua",
       "\t\tif s.owed then text = text .. \" \" .. L[\"People who buff me are always offered one back.\"] end\n",
       "",
       "presets: favours not said to be always returned",
       expect="does not say favours are always returned", script=S)

# The group's extras said with the group off, or left out.
mutate("Options.lua",
       "\tif s.group then\n\t\t-- Guarded: the reagent count",
       "\tif true then\n\t\t-- Guarded: the reagent count",
       "presets: group extras with the group off",
       expect="with the group off, the summary still talks about the group", script=S)

mutate("Options.lua",
       "\t\tparts[#parts + 1] = L[\"Ready checks and the just-revived go first.\"]\n",
       "",
       "presets: who goes first left out",
       expect="the summary leaves out who goes first", script=S)

mutate("Options.lua",
       "\tif pr.readyCheck and pr.revived then\n",
       "\tif pr.readyCheck or pr.revived then\n",
       "presets: ready check alone said as both",
       expect="the ready check alone is not said", script=S)

mutate("Options.lua",
       "\tif gb.use and ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs() then\n",
       "\tif ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs() then\n",
       "presets: group buffs said while off",
       expect="group buffs are said with Use group buffs off", script=S)

mutate("Options.lua",
       "\t\t\t\tif count == 0 then\n\t\t\t\t\tparts[1] = L[",
       "\t\t\t\tif false then\n\t\t\t\t\tparts[1] = L[",
       "presets: an empty bag said as a count",
       expect="an empty bag is not said", script=S)

mutate("Options.lua",
       "\t\t\t\t\tparts[1] = L[\"Group buffs when %d of a party need it (%s: %d in bags).\"]\n",
       "\t\t\t\t\tparts[1] = L[\"Group buffs when %d of a party need it.\"]\n",
       "presets: group buffs without their reagent",
       expect="the group buffs and their reagent are not said", script=S)

# A /thank that cannot fire summed up as if it could.
mutate("Options.lua",
       "\t\tif S().owed then return L[\"Only /thank.\"] end\n",
       "\t\tdo return L[\"Only /thank.\"] end\n",
       "presets: a /thank waiting on favours said as working",
       expect="with People who buff me off, Just /thank them reads", script=S)

mutate("Options.lua",
       "\tlocal thankLine = thanks and (S().owed and L[\"Also /thanks people who buff you.\"]\n",
       "\tlocal thankLine = thanks and (true and L[\"Also /thanks people who buff you.\"]\n",
       "presets: a line and a /thank waiting on favours",
       expect="with People who buff me off, a line and a /thank reads", script=S)

# --- the key ---

mutate("Options.lua",
       "\t\tfor _, old in ipairs(Setup.Keys()) do SetBinding(old) end\n",
       "",
       "setup: the old key kept",
       expect="the old key still buffs as well", script=S)

mutate("Options.lua",
       "\tif InCombatLockdown() or not Setup.CanBind() then return false end\n",
       "\tif not Setup.CanBind() then return false end\n",
       "setup: a key changed in combat",
       expect="a key was changed in combat", script=S)

mutate("Options.lua",
       "\t\t\t\tns.addon:Print(L[\"%s was bound to %s; it now buffs the prompted player.\"]\n",
       "\t\t\t\tlocal _ = (L[\"%s was bound to %s; it now buffs the prompted player.\"]\n",
       "setup: a key taken silently",
       expect="taking a key from Jump said nothing", script=S)

mutate("Options.lua",
       "\t\tSaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)\n",
       "\t\tSaveBindings(1)\n",
       "setup: saved to the wrong binding set",
       expect="the binding was not saved to the set in use", script=S)

# --- the macro and the key bindings window ---

mutate("Options.lua",
       "\treturn ok and type(index) == \"number\" and index > 0\n",
       "\treturn ok and type(index) == \"number\" and index >= 0\n",
       "setup: a macro nobody made",
       expect="a macro nobody made counts as made", script=S)

mutate("Options.lua",
       "function Setup.OpenBindings()\n\tif InCombatLockdown() then return false end\n",
       "function Setup.OpenBindings()\n",
       "setup: key bindings opened in combat",
       expect="the key bindings opened in combat", script=S)

mutate("Options.lua",
       "\tif InCombatLockdown() then return false end\n\tns.CloseOptions()\n",
       "\tif InCombatLockdown() then return false end\n",
       "setup: the options window left over the key bindings",
       expect="the options window stayed up over the key bindings", script=S)

mutate("Options.lua",
       "\treturn type(KeyBindingFrame_LoadUI) == \"function\"\n",
       "\treturn true\n",
       "setup: the key bindings button with no way there",
       expect="a client with no way to the key bindings offers the button", script=S)
