# Reactive wards must require a concrete UNIT_COMBAT damage event.

S = "runscenarios.py"
N = "combat-wards: "

mutate("Modules/Combat/Wards.lua",
       'if plain(unit) ~= "player" or plain(action) ~= "DAMAGE" then return nil end\n',
       "if plain(unit) ~= \"player\" then return nil end\n",
       "combat-wards: healing reveals a reactive ward",
       expect=N + "classic damage reveals only a known matching ward", script=S)

mutate("Modules/Combat/Wards.lua",
       "if not Wards.Known(row) then\n\t\tDisarmRow(row)\n\t\treturn\n\tend\n",
       "if not Wards.Known(row) then\n"
       "\t\trow.id, row.name = row.ranks[1], row.key == \"fire\" and \"Fire Ward\" or \"Frost Ward\"\n"
       "\tend\n",
       "combat-wards: an unknown ward is armed",
       expect=N + "classic damage reveals only a known matching ward", script=S)

mutate("Modules/Combat/Wards.lua",
       "local fire, frost = SchoolHas(mask, FIRE), SchoolHas(mask, FROST)\n",
       "local fire, frost = true, false\n",
       "combat-wards: the school mask is ignored",
       expect=N + "classic damage reveals only a known matching ward", script=S)

mutate("Modules/Combat/Wards.lua",
       "if Wards.Applies() and Usable(row) and not WardAura() then\n",
       "if Usable(row) and not WardAura() then\n",
       "combat-wards: the option no longer gates damage",
       expect=N + "classic damage reveals only a known matching ward", script=S)

mutate("Modules/Combat/Wards.lua",
       "if usable ~= true or noMana == true then return false end\n",
       "if false then return false end\n",
       "combat-wards: an unusable ward is revealed",
       expect=N + "classic damage reveals only a known matching ward", script=S)

mutate("Modules/Combat/Wards.lua",
       "local ready = ns.CastReady and ns.CastReady(row.id)\n\treturn ready == true\n",
       "return true\n",
       "combat-wards: a cooling ward is revealed",
       expect=N + "classic damage reveals only a known matching ward", script=S)
