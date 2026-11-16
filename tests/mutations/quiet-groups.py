# Mutations for Say nothing in a party and Say nothing in a raid (What I say;
# speech.quietInParty, speech.quietInRaid): the rule in Speech.lua
# (ns.GroupQuiet, read by ns.ChannelOpen), the bar macro's copy (Prompt/Macro.lua),
# the settings string (Commands.lua, SHARE_QUIET), the defaults (Core.lua), the
# layout (Options/Window/Layout.lua) and /manners debug's line. Each is caught by
# the scenario in tests/scenarios/quiet-groups.lua it names.

S = "runscenarios.py"

mutate("Speech.lua",
       "\tif ns.GroupQuiet() then return false end\n",
       "",
       "quiet-groups: the switches leave the line in",
       expect="quiet-groups: a party member hears no line with Say nothing in a party", script=S)

mutate("Speech.lua",
       "\tif ns.GroupQuiet() then return false end\n",
       "\tif ns.GroupQuiet() == \"raid\" then return false end\n",
       "quiet-groups: a quiet party still talks to a passer-by",
       expect="quiet-groups: a passer-by hears no line while you are in a quiet party", script=S)

mutate("Speech.lua",
       "\t\treturn speech.quietInRaid == true and \"raid\" or nil\n",
       "\t\treturn speech.quietInParty == true and \"raid\" or nil\n",
       "quiet-groups: a raid read by the party's switch",
       expect="quiet-groups: no line in a raid with Say nothing in a raid", script=S)

mutate("Speech.lua",
       "\t\treturn speech.quietInRaid == true and \"raid\" or nil\n",
       "\t\tif speech.quietInRaid == true then return \"raid\" end\n",
       "quiet-groups: a raid falls through to the party's switch",
       expect="quiet-groups: Say nothing in a party leaves a raid speaking", script=S)

mutate("Speech.lua",
       "\tif speech.quietInParty == true and ns.plain(IsInGroup and IsInGroup()) == true then return \"party\" end\n",
       "\tif speech.quietInParty == true then return \"party\" end\n",
       "quiet-groups: quiet with no group at all",
       expect="quiet-groups: solo, both switches leave the line", script=S)

mutate("Speech.lua",
       "\tif speech.quietInParty == true and ns.plain(IsInGroup and IsInGroup()) == true then return \"party\" end\n",
       "\tif speech.quietInRaid == true and ns.plain(IsInGroup and IsInGroup()) == true then return \"party\" end\n",
       "quiet-groups: a party read by the raid's switch",
       expect="quiet-groups: Say nothing in a raid leaves a party speaking", script=S)

mutate("Prompt/Macro.lua",
       "\t\tif phrase then\n\t\t\tlocal withLine = BarLines(true)\n",
       "\t\tif S.phraseText then\n\t\t\tphrase = S.phraseText\n\t\t\tlocal withLine = BarLines(true)\n",
       "quiet-groups: the bar macro carries the line the prompt leaves out",
       expect="quiet-groups: the bar macro agrees with the prompt", script=S)

mutate("Commands.lua",
       "\t\t\t\tif holder[field.key] == true then\n\t\t\t\t\tif value ~= true and speaking then kept.words = true end\n",
       "\t\t\t\tif false then\n\t\t\t\t\tif value ~= true and speaking then kept.words = true end\n",
       "quiet-groups: a paste switches a quiet group off",
       expect="quiet-groups: a pasted string can only make you quieter", script=S)

mutate("Commands.lua",
       "\t\t\t\t\tholder[field.key] = value == true\n",
       "\t\t\t\t\tholder[field.key] = false\n",
       "quiet-groups: a paste never carries a quiet group",
       expect="quiet-groups: a pasted string can only make you quieter", script=S)

mutate("Core.lua",
       "\t\t\tquietInRaid = false,\n",
       "\t\t\tquietInRaid = true,\n",
       "quiet-groups: Say nothing in a raid on by default",
       expect="quiet-groups: the switches sit under Say a line, off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"click.quietInParty\", indent = true },\n",
       "\t\t\t\t\t\"click.quietInParty\",\n",
       "quiet-groups: Say nothing in a party not indented",
       expect="quiet-groups: the switches sit under Say a line, off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t[\"click.quietInParty\"] = true, [\"click.quietInRaid\"] = true,\n",
       "\t\t\t[\"click.quietInParty\"] = true,\n",
       "quiet-groups: Say nothing in a raid off the short list",
       expect="quiet-groups: the switches sit under Say a line, off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"click.quietInRaid\"] = \"click.enabled\",\n",
       "",
       "quiet-groups: search not told Say nothing in a raid's switch",
       expect="quiet-groups: the switches sit under Say a line, off by default", script=S)

mutate("Commands.lua",
       "\t\tif quiet == \"party\" then\n",
       "\t\tif false then\n",
       "quiet-groups: /manners debug silent about a quiet party",
       expect="quiet-groups: the thank-you whisper still goes, and debug says why no line", script=S)

mutate("Speech.lua",
       "\tif ns.InBattleground() then return nil end\n",
       "",
       "quiet-groups: a party or raid switch silences a battleground",
       expect="quiet-groups: in a battleground or an arena Say my line there decides", script=S)

mutate("Commands.lua",
       "\t\t\t\t\tif value ~= true and speaking then kept.words = true end\n",
       "",
       "quiet-groups: a paste keeps a quiet group on unsaid",
       expect="quiet-groups: a pasted string can only make you quieter", script=S)
