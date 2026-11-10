# Mutations for holding one buff off one person after the game says it cannot
# land (Queue.lua NoteRefusal), a mage's scrolls as consumables (Core.lua
# OwnItemsHeldToDungeons) and a right-click's own length (Queue.lua SkipSeconds,
# Core.lua defaults and limits, Prompt/Press.lua). Each is caught by the
# scenario in tests/scenarios/buffheld.lua (or itemsdungeon.lua) that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif buffKey and OneOf(why, THIS_BUFF) then\n",
       "\t\tif false then\n",
       "buffheld: a stronger buff already on them is never read",
       expect="buffheld: a stronger buff already on them holds that buff off", script=S)

mutate("Queue.lua",
       "\tlocal THIS_BUFF_SECONDS = 600\n",
       "\tlocal THIS_BUFF_SECONDS = 20\n",
       "buffheld: the buff is held off for twenty seconds",
       expect="buffheld: a stronger buff already on them holds that buff off", script=S)

mutate("Queue.lua",
       "\tlocal THIS_BUFF = { \"SPELL_FAILED_AURA_BOUNCED\", \"SPELL_FAILED_LOWLEVEL\" }\n",
       "\tlocal THIS_BUFF = { \"SPELL_FAILED_AURA_BOUNCED\" }\n",
       "buffheld: too low a level is not read",
       expect="buffheld: too low a level holds that buff off too", script=S)

mutate("Queue.lua",
       "\t\t\t\tns.MarkAttempted(member, buffKey, THIS_BUFF_SECONDS, true)\n\t\t\tend\n\t\t\treturn\n",
       "\t\t\t\tns.MarkAttempted(member, buffKey, THIS_BUFF_SECONDS, true)\n\t\t\tend\n",
       "buffheld: it counts towards backing the person off",
       expect="buffheld: it does not count towards backing the person off", script=S)

mutate("Queue.lua",
       "\t\t\tfor _, member in ipairs(members or {}) do\n",
       "\t\t\tfor _, member in ipairs({}) do\n",
       "buffheld: a group cast holds off only the one it was aimed at",
       expect="buffheld: a group cast holds the buff off everyone it covered", script=S)

mutate("Queue.lua",
       "\t\t\tns.MarkAttempted(name, buffKey, THIS_BUFF_SECONDS, true)\n",
       "\t\t\tns.BlockPerson(name, THIS_BUFF_SECONDS, true)\n",
       "buffheld: the whole person is held off, not the buff",
       expect="buffheld: only that buff, only that person", script=S)

mutate("Core.lua",
       "\t\tif family.consumable then return true end\n\t\t-- A mage's scrolls on Forever too (the weapon imbue, the familiar), asked\n\t\t-- for on CurseForge: they are used up like the rest.\n\t\tif family.isScroll then return true end\n",
       "\t\tif family.consumable then return true end\n\t\t-- A mage's scrolls on Forever too (the weapon imbue, the familiar), asked\n\t\t-- for on CurseForge: they are used up like the rest.\n",
       "buffheld: a mage's scrolls are not held to dungeons",
       expect="buffheld: a mage's scrolls count as consumables", script=S)

mutate("Queue.lua",
       "\t\treturn (db and db.timing.skipSeconds) or (db and db.timing.retryCooldown) or 12\n",
       "\t\treturn (db and db.timing.retryCooldown) or 12\n",
       "buffheld: a right-click skips for the retry cooldown",
       expect="buffheld: a right-click's length is its own setting", script=S)

mutate("Core.lua",
       "\t\t\tskipSeconds = 12,\n",
       "\t\t\tskipSeconds = 30,\n",
       "buffheld: the skip's default moved",
       expect="buffheld: a right-click's length is its own setting", script=S)

mutate("Core.lua",
       "\t{ \"timing\", \"skipSeconds\", 3, 1800 },\n",
       "\t{ \"timing\", \"skipSeconds\", 3, 100000 },\n",
       "buffheld: the skip is not capped",
       expect="buffheld: a right-click's length is its own setting", script=S)

mutate("Prompt/Press.lua",
       "\t\tns.BlockPerson(victim, ns.SkipSeconds())\n",
       "\t\tns.BlockPerson(victim)\n",
       "buffheld: a right-press skips for the retry cooldown",
       expect="buffheld: a right-click on the prompt skips for that long", script=S)

mutate("Options/Advanced.lua",
       "\t\t\t\tmax = 1800,\n",
       "\t\t\t\tmax = 60,\n",
       "buffheld: the slider stops at a minute",
       expect="buffheld: a skip has a slider on When to offer", script=S)
