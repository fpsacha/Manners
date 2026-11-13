# Mutations for the fight's rota (Prompt/Fight.lua and the places that call
# it). Caught by tests/scenarios/fight-rota.lua.

S = "runscenarios.py"
FIGHT = "Prompt/Fight.lua"
EACH = "fight-rota: each press in a fight casts at the next person"

mutate("Core.lua",
       "\tif ns.Prompt then ns.Guard(\"rota for the fight\", ns.Prompt.ArmFightRota, ns.Prompt) end\n",
       "",
       "fight-rota: the pull arms no rota",
       expect=EACH, script=S)

mutate(FIGHT,
       "\t\theader.rotaWrapped = pcall(_G.SecureHandlerWrapScript, R.button, \"OnClick\", header, ROTA_PRE, ROTA_POST) or nil\n",
       "\t\theader.rotaWrapped = nil\n",
       "fight-rota: the prompt's click never wrapped",
       expect="the prompt's click is not wrapped for the rota", script=S)

mutate(FIGHT,
       "\tlocal i = (control:GetAttribute(\"manners-rota-i\") or 1) % n + 1\n",
       "\tlocal i = control:GetAttribute(\"manners-rota-i\") or 1\n",
       "fight-rota: the snippet stays on the one person",
       expect=EACH, script=S)

mutate(FIGHT,
       "\tlocal i = (control:GetAttribute(\"manners-rota-i\") or 1) % n + 1\n",
       "\tlocal i = math.min(n, (control:GetAttribute(\"manners-rota-i\") or 1) + 1)\n",
       "fight-rota: the rota stops on its last instead of coming round",
       expect="the rota does not come round in the same order", script=S)

mutate(FIGHT,
       "\tself:SetAttribute(\"macrotext1\", text)\n\tself:SetAttribute(\"macrotext\", text)\n",
       "\tself:SetAttribute(\"macrotext\", text)\n",
       "fight-rota: the step written where a left press does not read it",
       expect=EACH, script=S)

mutate(FIGHT,
       "\tif button ~= \"LeftButton\" or down == false then return end\n",
       "\tif down == false then return end\n",
       "fight-rota: a right press steps the rota",
       expect="a right press stepped the rota", script=S)

mutate(FIGHT,
       "\tif (control:GetAttribute(\"manners-rota-n\") or 0) < 2 then return end\n\treturn nil, \"step\"\n",
       "\treturn nil, \"step\"\n",
       "fight-rota: the first half lets the second run with no rota",
       expect="fight-rota:", script=S)

mutate(FIGHT,
       "\tcontrol:SetAttribute(\"manners-rota-i\", i)\n\tlocal text = control",
       "\tlocal text = control",
       "fight-rota: the second half forgets where it stands",
       expect=EACH, script=S)

mutate(FIGHT,
       "\tif not (db and db.prompt.fightRota ~= false and header.rotaWrapped) then return end\n",
       "\tif not (db and header.rotaWrapped) then return end\n",
       "fight-rota: the switch reads nothing",
       expect="switched off, the pull still made a rota", script=S)

mutate(FIGHT,
       "\tif header:GetAttribute(\"manners-hide\") or S.testMode then return end\n",
       "\tif S.testMode then return end\n",
       "fight-rota: a rota armed on a prompt hidden for the fight",
       expect="a rota was armed on a prompt hidden for the fight", script=S)

mutate(FIGHT,
       "\t\tif #entries >= ROTA_MAX then break end\n",
       "",
       "fight-rota: a rota of everybody in sight",
       expect="over its most of", script=S)

mutate(FIGHT,
       "\tif #entries < 2 then return end\n\tfor i, text in ipairs(texts) do",
       "\tfor i, text in ipairs(texts) do",
       "fight-rota: a rota of one",
       expect="for one person", script=S)

mutate("Prompt/Press.lua",
       "\tif down ~= false and InCombatLockdown() then Prompt:SyncFightRota() end\n",
       "",
       "fight-rota: the panel left on the person the fight began with",
       expect="the panel is about", script=S)

mutate(FIGHT,
       "\tS.current, S.frozenEntry, S.armed = entry, nil, rota.records[i] or nil\n",
       "\tS.frozenEntry, S.armed = nil, rota.records[i] or nil\n",
       "fight-rota: the bookkeeping left on the person the fight began with",
       expect="the panel is about", script=S)

mutate("Prompt/Refresh.lua",
       "\t\t\t\t\tlocal at, of = self:FightRotaAt()\n",
       "\t\t\t\t\tlocal at, of = nil, nil\n",
       "fight-rota: the panel does not say which of how many",
       expect="the second line reads", script=S)

mutate("Core.lua",
       "\tif ns.Prompt then ns.Guard(\"fight rota release\", ns.Prompt.ReleaseFightRota, ns.Prompt) end\n",
       "",
       "fight-rota: the rota left set after the fight",
       expect="the rota is still set after the fight", script=S)

mutate("Prompt/Macro.lua",
       "\tif #text > ns.MACRO_LIMIT then return nil end\n\treturn text, record\n",
       "\treturn text, record\n",
       "fight-rota: a macro too long for the client put in the rota",
       expect="a macro too long for the client is in the rota", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return P().hideInFight == true end,\n",
       "\t\t\t\tdisabled = function() return false end,\n",
       "fight-rota: the switch live with the prompt hidden for the fight",
       expect="the switch is live with the prompt hidden for the fight", script=S)

mutate(FIGHT,
       "\t\tif entry ~= top and entry.buff and not (entry.name == top.name and entry.buff.key == top.buff.key)\n\t\t\tand not Reached(entry) then\n",
       "\t\tif entry ~= top and entry.buff and not (entry.name == top.name and entry.buff.key == top.buff.key) then\n",
       "fight-rota: a group cast's members each given a press of their own",
       expect="nobody a cast in the rota already reaches", script=S)

mutate(FIGHT,
       "\t\treturn wide[key] == true and entry.inGroup == true and not entry.groupCast\n",
       "\t\treturn false\n",
       "fight-rota: a cast for the whole group pressed again for each of them",
       expect="one cast lands on the whole group", script=S)
