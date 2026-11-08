# Mutations for flasks, elixirs and stat scrolls (Buffs.lua CONSUME and
# ns.ConsumableAuras, Consumables.lua, Core.lua ReadConsumable and OwnVerdict,
# Options/Who.lua, the layout, Prompt/Macro.lua allyscroll, Clicks.lua's bar
# shape): the families on every class of four clients, off by default, shown
# with one in the bags, read by the auras' ids, a flask in both elixir slots on
# Burning Crusade and Mists, a scroll per stat used on you by name and never
# over a class buff of its stat, held back mounted and, with the switch, out of
# dungeons. Each is caught by the scenario in tests/scenarios/consume-buffs.lua
# that names it (or layout.lua).

S = "runscenarios.py"

# --- the data and the families ---

mutate("Consumables.lua",
       "\ttbc = {\n\t\tflaskFills = true,\n",
       "\ttbc = {\n",
       "consume-buffs: Burning Crusade's flask fills no elixir slot",
       expect="consume-buffs: every client's table is whole and in order", script=S)

mutate("Buffs.lua",
       "\tfor _, family in ipairs(CONSUME[client] or {}) do\n\t\ttable.insert(list, at, family)\n",
       "\tfor _, family in ipairs(client == \"mists\" and CONSUME[client] or {}) do\n\t\ttable.insert(list, at, family)\n",
       "consume-buffs: the families on Mists' lists alone",
       expect="consume-buffs: every class has the families, retail none", script=S)

mutate("Buffs.lua",
       "\t\tif elixir and flask and data.flaskFills then\n",
       "\t\tif elixir and flask and data.flaskFills and false then\n",
       "consume-buffs: a flask fills no elixir slot",
       expect="consume-buffs: a flask fills both elixir slots on Burning Crusade and Mists", script=S)

mutate("Buffs.lua",
       "\t\tif elixir and flask and data.flaskFills then\n",
       "\t\tif elixir and flask then\n",
       "consume-buffs: a flask fills the elixir slot everywhere",
       expect="consume-buffs: a flask beside an elixir on Classic Era and Forever", script=S)

mutate("Buffs.lua",
       "\t\t\t\tnameFromItem = label, onAlly = ally, castOnOthers = ally }\n",
       "\t\t\t\tnameFromItem = label, castOnOthers = ally }\n",
       "consume-buffs: a scroll used on whoever is targeted",
       expect="consume-buffs: a scroll is used on you by name", script=S)

mutate("Buffs.lua",
       "\t\t\t\tnameFromItem = label, onAlly = ally, castOnOthers = ally }\n",
       "\t\t\t\tnameFromItem = label, onAlly = ally }\n",
       "consume-buffs: a scroll from somebody else taken for your own aura",
       expect="consume-buffs: a scroll stays a blocker and another's is their favour", script=S)

mutate("Buffs.lua",
       "\t\t\tfor _, id in ipairs(buff.blockers or {}) do blocked = blocked or own[id] == true end\n",
       "",
       "consume-buffs: a scroll offered over the class buff of its stat",
       expect="consume-buffs: a Scroll of Intellect waits under Arcane Intellect", script=S)

mutate("Buffs.lua",
       "\tfor _, id in ipairs(family.covers or {}) do add(id) end\n",
       "",
       "consume-buffs: what covers a family never read",
       expect="consume-buffs: a flask fills both elixir slots on Burning Crusade and Mists", script=S)

# --- off until switched on, and the page ---

mutate("Core.lua",
       "\t\tif family.consumable then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "",
       "consume-buffs: on by default",
       expect="consume-buffs: off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif family.consumable then return pick() == \"off\" and not Consumable.Held(family) end\n",
       "",
       "consume-buffs: the switch hidden until switched on",
       expect="consume-buffs: off by default", script=S)

mutate("Options/Who.lua",
       "\t\tif type(n) == \"number\" and n > 0 then return true end\n\tend\n\treturn false\nend\n",
       "\t\tif type(n) == \"number\" and n > 0 then return false end\n\tend\n\treturn false\nend\n",
       "consume-buffs: the switch hidden with one in the bags",
       expect="consume-buffs: off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_flask\", indent = true },\n",
       "",
       "consume-buffs: the flask switch not placed on the page",
       expect="own_flask", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tname = L[\"Consumables only in dungeons and raids\"],\n\t\t\t\tdesc = L[\"On: the reminder for an oil or a stone for your weapon, for food, and for a flask, an elixir or a scroll comes up only in a dungeon or a raid, not out in the world. Poisons and fishing lures are not held back.\"],\n",
       "\t\t\t\tname = L[\"Oils, stones and food only in dungeons and raids\"],\n\t\t\t\tdesc = L[\"On: the reminder for an oil or a stone for your weapon, and for food, comes up only in a dungeon or a raid, not out in the world. Poisons and fishing lures are not held back.\"],\n",
       "consume-buffs: the dungeon switch's words left as they were",
       expect="consume-buffs: held to dungeons and raids with the switch", script=S)

# --- the reading ---

mutate("Core.lua",
       "\t\tif family.consumable then return ReadConsumable(family, GetTime()) end\n",
       "",
       "consume-buffs: read as a spell of yours",
       expect="consume-buffs: a flask fills both elixir slots on Burning Crusade and Mists", script=S)

mutate("Core.lua",
       "\t\t\tlocal aura = byId(\"player\", id)\n\t\t\tif Withheld(aura) then\n",
       "\t\t\tlocal aura = byId(\"player\", id)\n\t\t\tif false then\n",
       "consume-buffs: a refused read taken as none",
       expect="consume-buffs: a flask up, or a refused read, is not offered", script=S)

mutate("Core.lua",
       "\t\t\telseif not refused and HiddenAura(id) then\n\t\t\t\trefused = true\n\t\t\tend\n\t\tend\n\t\tif refused then return nil end\n\t\treturn false\n\tend\n\tlocal function ReadConsumable",
       "\t\t\tend\n\t\tend\n\t\tif refused then return nil end\n\t\treturn false\n\tend\n\tlocal function ReadConsumable",
       "consume-buffs: an aura the client keeps secret read as missing",
       expect="consume-buffs: a flask up, or a refused read, is not offered", script=S)

mutate("Core.lua",
       "\t\t\telseif type(aura) == \"table\" then\n\t\t\t\treturn true, Left(aura, now)\n",
       "\t\t\telseif type(aura) == \"table\" and false then\n\t\t\t\treturn true, Left(aura, now)\n",
       "consume-buffs: a flask on you not seen",
       expect="consume-buffs: a flask up, or a refused read, is not offered", script=S)

mutate("Core.lua",
       "\t\tlocal ok, up, left = pcall(ScanConsumable, byId, ns.ConsumableAuras(family), now)\n",
       "\t\tlocal ok, up, left = true, ScanConsumable(byId, ns.ConsumableAuras(family), now)\n",
       "consume-buffs: a read that throws taken past",
       expect="consume-buffs: a flask up, or a refused read, is not offered", script=S)

# --- held back ---

mutate("Core.lua",
       "\t\tif family.consumable and type(_G.IsMounted) == \"function\" and plain(_G.IsMounted()) == true then\n",
       "\t\tif false then\n",
       "consume-buffs: offered mounted",
       expect="consume-buffs: mounted, nothing is offered", script=S)

mutate("Core.lua",
       "\t\tif family.consumable then return true end\n",
       "",
       "consume-buffs: not held to dungeons",
       expect="consume-buffs: held to dungeons and raids with the switch", script=S)

# --- the press ---

mutate("Prompt/Macro.lua",
       "\t\tif entry.buff and entry.buff.onAlly then return \"allyscroll\" end\n",
       "",
       "consume-buffs: a scroll used on whoever is targeted, by the macro",
       expect="consume-buffs: a scroll is used on you by name", script=S)

mutate("Prompt/Macro.lua",
       "\tlocal restore = not StillTargeted(entry) or Prompt.armedForFight == true\n\treturn lines, restore,\n\t\t{ targeted = true, selfCast = false, onSelf = true, aimedAt = entry.targetName or entry.name }\nend\n\n-- Target them",
       "\treturn lines, false,\n\t\t{ targeted = true, selfCast = false, onSelf = true, aimedAt = entry.targetName or entry.name }\nend\n\n-- Target them",
       "consume-buffs: your target not handed back after a scroll",
       expect="consume-buffs: a scroll is used on you by name", script=S)

mutate("Clicks.lua",
       "\t\telseif command == \"use\" and arg:match(\"^item:%d+$\") and OneOfMine(select(2, Command(rest[2]))) then\n\t\t\ti = i + 1\n",
       "",
       "consume-buffs: the bar's scroll used on you taken for the player's",
       expect="consume-buffs: the bar macro keeps a scroll used on you as its own", script=S)
