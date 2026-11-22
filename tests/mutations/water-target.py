# Mutations for water and food for your target and the filled trade window
# (Courtesy.lua, Aimed and Fill). Each undoes one rule and is caught by the
# scenario in tests/scenarios/water-target.lua that names it.

S = "runscenarios.py"

P = "water-target: "
OFF = P + "switch off, nothing is offered"
WHO = P + "nobody but a friendly player is offered: not yourself, an enemy, an NPC or another mage"
FOOD = P + "a warrior is offered food alone"
NOLEVEL = P + "a withheld level offers nothing on Classic, and a withheld power offers food"
LOW = P + "a low-level target gets the low rank and never a stack above their level"
ONE = P + "One stack puts one of each"
FILL = P + "Fill the trade window puts in as many stacks as fit, water and food in turn, and leaves the player's own slots alone"
ONLY = P + "nothing but conjured water and food goes in the trade"
CURSOR = P + "the cursor holding something, nothing goes in and nothing is dropped"
REST = P + "once traded or skipped they are left alone for ten minutes"
FAR = P + "a target past trade range is not offered the trade"
THEIRS = P + "a target who opens the trade themselves gets nothing put in"
OPTIONS = P + "the switch shows for a mage alone, How much to trade beside it, and both reset"
RESET = "model: the reset puts who back"

# The switch is the first thing Aimed reads.
mutate("Courtesy.lua",
       "\tif not (db and db.sources.courtesyTarget == true) then return nil end\n",
       "\tif not db then return nil end\n",
       "water-target: the target is offered with its switch off",
       expect=OFF, script=S)

# Somebody you cannot help (an enemy, or an answer withheld) is skipped.
mutate("Courtesy.lua",
       "\t\tor plain(UnitCanAssist(\"player\", \"target\")) ~= true then\n",
       "\t\tor false then\n",
       "water-target: an enemy target is offered water",
       expect=WHO, script=S)

# Yourself is never your own target's offer.
mutate("Courtesy.lua",
       "\tif not full or ns.IsPlayerName(full) then return nil end\n",
       "\tif not full then return nil end\n",
       "water-target: you are offered water for yourself",
       expect=WHO, script=S)

# Water for everybody, whatever they run on.
mutate("Courtesy.lua",
       "\t\tif mana == true then keys[\"courtesy:water\"] = true end\n",
       "\t\tkeys[\"courtesy:water\"] = true\n",
       "water-target: water is offered to a class without mana",
       expect=FOOD, script=S)

# A level that cannot be read is guessed at.
mutate("Courtesy.lua",
       "\t\t\tif row.level or row.needs then return nil, \"nolevel\" end\n",
       "\t\t\tif false then return nil, \"nolevel\" end\n",
       "water-target: a target with a withheld level is offered the top rank",
       expect=NOLEVEL, script=S)

# A target below every rank learned gets the lowest one.
mutate("Courtesy.lua",
       "\tif st.targeted and not conjure and lowest then return nil, \"level\" end\n",
       "\tif false then return nil, \"level\" end\n",
       "water-target: a target below every learned rank gets the lowest",
       expect=LOW, script=S)

# One stack: the cap is ignored.
mutate("Courtesy.lua",
       "\t\t\tif nextFree <= #free and list.put < perKind and spot then\n",
       "\t\t\tif nextFree <= #free and spot then\n",
       "water-target: One stack fills the window all the same",
       expect=ONE, script=S)

# Every trade slot counts as free, the player's own included.
mutate("Courtesy.lua",
       "\t\tif not link(i) then free[#free + 1] = i end\n",
       "\t\tif true then free[#free + 1] = i end\n",
       "water-target: the player's own trade slots are overwritten",
       expect=FILL, script=S)

# Anything in the bags goes in, not only what the rows list.
mutate("Courtesy.lua",
       "\t\t\tlists[#lists + 1] = { key = key, slots = slots, at = 1, put = 0 }\n",
       "\t\t\tfor _, spots in pairs(held) do for _, spot in ipairs(spots) do slots[#slots + 1] = spot end end\n"
       "\t\t\tlists[#lists + 1] = { key = key, slots = slots, at = 1, put = 0 }\n",
       "water-target: every item in the bags can go in the trade",
       expect=ONLY, script=S)

# The cursor is not looked at before an item is picked up.
mutate("Courtesy.lua",
       "\tif type(_G.GetCursorInfo) == \"function\" and _G.GetCursorInfo() then return false end\n\t_G.C_Container.PickupContainerItem",
       "\t_G.C_Container.PickupContainerItem",
       "water-target: an item is picked up over what the cursor holds",
       expect=CURSOR, script=S)

# A trade made is not remembered.
mutate("Courtesy.lua",
       "\t\tRest(who or plain(UnitGUID(\"NPC\")) or (type(request) == \"table\" and request.name) or name, GetTime())\n",
       "\t\tlocal _ = 0\n",
       "water-target: a target just traded with is offered again at once",
       expect=REST, script=S)

# A right-click is not remembered either.
mutate("Prompt/Press.lua",
       "\t\tif ns.Courtesy and ns.Courtesy.Skipped then ns.Courtesy.Skipped(victim) end\n",
       "",
       "water-target: a skipped target comes back when the skip ends",
       expect=REST, script=S)

# Out of reach is never seen.
mutate("Courtesy.lua",
       "and plain(_G.CheckInteractDistance(unit, 2)) == false then",
       "and plain(_G.CheckInteractDistance(unit, 2)) == \"never\" then",
       "water-target: a target out of reach is offered the trade",
       expect=FAR, script=S)

# The target who opens the trade is not looked at.
mutate("Courtesy.lua",
       "\tfor i = #(list or {}), 1, -1 do requests[#requests + 1] = list[i] end\n",
       "\tfor i = #(list or {}), 1, -1 do requests[#requests + 1] = list[i] end\n"
       "\tif aimed.request then requests[#requests + 1] = aimed.request end\n",
       "water-target: a trade the target opened is filled",
       expect=THEIRS, script=S)

# The control shows for every class.
mutate("Options/Who.lua",
       "\t\t\t\torder = 14.45,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = function() return not ns.Courtesy.Has(\"courtesyRefresh\") end,\n",
       "\t\t\t\torder = 14.45,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = function() return false end,\n",
       "water-target: a warlock is shown the water and food switch",
       expect=OPTIONS, script=S)

# The page's reset leaves the two settings.
mutate("Options/Advanced.lua",
       "\t\t\"sources.courtesyTarget\", \"sources.courtesyAmount\",\n",
       "",
       "water-target: the page's reset leaves the target's water and food",
       expect=RESET, script=S)

# The mana floor holds the unasked target offer.
mutate("Courtesy.lua",
       "\tif aim and ns.SavingMana and ns.SavingMana() ~= nil then\n",
       "\tif false then\n",
       "water-target: the target is offered below the mana floor",
       expect=P + "no unreadable-buff line on the target's tooltip, and the mana floor holds the offer", script=S)

# The full tooltip of a target's offer warns of nothing unreadable.
mutate("Prompt/Button.lua",
       "\tif entry.checked and entry.known == nil and not entry.courtesy then\n",
       "\tif entry.checked and entry.known == nil then\n",
       "water-target: the target's tooltip warns of an unreadable buff",
       expect=P + "no unreadable-buff line on the target's tooltip, and the mana floor holds the offer", script=S)
