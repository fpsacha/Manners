# Mutations for a class's courtesies on request (Courtesy.lua): the reader's
# hook (Requests.lua), the queue's two (Queue.lua), the prompt's (Core.lua
# BuffInfo, Prompt/Macro.lua, Prompt/Press.lua, Prompt/Paint.lua), the rules in
# Courtesy.lua itself and the settings (Core.lua, Options/Who.lua,
# Options/Advanced.lua). Each is caught by the scenario in
# tests/scenarios/courtesy.lua that names it.

S = "runscenarios.py"

WATER = "courtesy: water asked for is conjured, then traded, and the trade is never accepted"
WORDS = "courtesy: the words that ask for one are heard, and no others"
SWITCH = "courtesy: each is off until ticked, and shown to the class that has it"
PORTAL = "courtesy: a portal is for the group, needs its rune and targets nobody"
STONE = "courtesy: a healthstone is created with a shard, then traded to whoever asked"
SUMMON = "courtesy: a summon targets the member who asked, hands nothing back, and needs a shard"
FIGHT = "courtesy: nothing is offered or left armed in a fight"
LEVEL = "courtesy: the water suits the level of whoever asked"
FAVOUR = "courtesy: a favour comes first, and an unasked buff gives way"
ALONE = "courtesy: water is offered with every buff switched off"
WELL = "courtesy: mists: a healthstone asked for is a Soulwell for the group"
TOOLTIP = "courtesy: the tooltip says what the press does, and a skip lets them go"
TOWN = "courtesy: Offer nothing in cities and inns holds a courtesy too"

# ------------------------------------------------------------ the reader
# The reader is never handed the courtesies' names: "water pls" asks for nothing.
mutate("Requests.lua",
       "\t\tif ns.Courtesy then ns.Courtesy.Named(words, lowered, found, covered, strict, Mark, Words) end\n",
       "",
       "courtesy: the reader is not told the courtesies' names",
       expect=WORDS, script=S)

# A city on its own is a portal asked for: "org pls", "uc?".
mutate("Courtesy.lua",
       "\t\t\tif (named and portalAt) or inside then\n",
       "\t\t\tif named or inside then\n",
       "courtesy: a city's name alone asks for a portal",
       expect=WORDS, script=S)

# "water and food pls": the "and" between two is a word of its own again.
mutate("Courtesy.lua",
       "\t\t\tif asks.joiners[word] then covered[i] = true end\n",
       "",
       "courtesy: two asked for at once are not read",
       expect=WORDS, script=S)

# The check-up's line for a request names no courtesy.
mutate("Requests.lua",
       "\t\t\t\tif ns.Courtesy then ns.Courtesy.Describe(request.keys, what) end\n",
       "",
       "courtesy: the check-up does not say what was asked for",
       expect=PORTAL, script=S)

# Nor why one is held back.
mutate("Requests.lua",
       "\t\tif ns.Courtesy then ns.Guard(\"courtesy lines\", ns.Courtesy.Lines, lines) end\n",
       "",
       "courtesy: the check-up says nothing of what is held back",
       expect=PORTAL, script=S)

# ------------------------------------------------------------ the switches
# On in a new profile: nobody asked to hand strangers water.
mutate("Core.lua",
       "\t\t\tcourtesyRefresh = false,\n",
       "\t\t\tcourtesyRefresh = true,\n",
       "courtesy: water and food on in a new profile",
       expect=SWITCH, script=S)

# Every courtesy answered once People who ask me in chat is on, ticked or not.
mutate("Courtesy.lua",
       "\treturn db ~= nil and db.sources.asked == true and db.sources[SETTING[name]] == true\n",
       "\treturn db ~= nil and db.sources.asked == true\n",
       "courtesy: answered with its own switch off",
       expect=SWITCH, script=S)

# The page's reset leaves the four switches as they are.
mutate("Options/Advanced.lua",
       "\t\t\"sources.courtesyRefresh\", \"sources.courtesyPortals\", \"sources.courtesyHealthstones\", \"sources.courtesySummons\",\n",
       "",
       "courtesy: the page's reset leaves the switches",
       expect=SWITCH, script=S)

# A mage is shown the warlock's switch.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return not (S().asked and ns.Courtesy.Has(\"courtesySummons\")) end,\n",
       "\t\t\t\thidden = function() return not S().asked end,\n",
       "courtesy: the summons switch shown to every class",
       expect=SWITCH, script=S)

# ------------------------------------------------------------ the queue
# The walk's queue never gets whoever asked.
mutate("Queue.lua",
       "\tif ns.Courtesy and ns.Courtesy.Standing(now) then ns.Guard(\"courtesies\", ns.Courtesy.Queue, queue, rejected, now, inTown, manaHoldsAsked) end\n",
       "",
       "courtesy: the queue is never handed whoever asked",
       expect=WATER, script=S)

# With no buff to give, the queue leaves before a courtesy is looked at.
mutate("Queue.lua",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0) and battle ~= \"fight\" and not ns.CureScanned() and ns.Courtesy and ns.Courtesy.Standing(now) then\n",
       "\tif false then\n",
       "courtesy: nothing offered with no buff to give",
       expect=ALONE, script=S)

# Offered in a fight.
mutate("Courtesy.lua",
       "\tlocal held = (InCombatLockdown() or (ns.Prompt and ns.Prompt.armedForFight == true)) and \"fight\"\n",
       "\tlocal held = (ns.Prompt and ns.Prompt.armedForFight == true) and \"fight\"\n",
       "courtesy: offered in a fight",
       expect=FIGHT, script=S)

# The pull's own repaint arms it, and the fight freezes it on the button.
mutate("Courtesy.lua",
       "\tlocal held = (InCombatLockdown() or (ns.Prompt and ns.Prompt.armedForFight == true)) and \"fight\"\n",
       "\tlocal held = InCombatLockdown() and \"fight\"\n",
       "courtesy: the pull leaves a courtesy armed for the fight",
       expect=FIGHT, script=S)

# The city rule does not hold a courtesy.
mutate("Courtesy.lua",
       "\t\telseif inTown and not (st.pointed and db.filters.quietTargets ~= true) then\n",
       "\t\telseif false then\n",
       "courtesy: offered in a city with Offer nothing in cities and inns on",
       expect=TOWN, script=S)

# A favour owed is pushed out by the water they asked for.
mutate("Courtesy.lua",
       "\t\t\t\t\t\t\twaits = entry.groupCast ~= nil or (entry.priority or 9) <= asked\n",
       "\t\t\t\t\t\t\twaits = false\n",
       "courtesy: a courtesy takes a favour's place",
       expect=FAVOUR, script=S)

# Two entries for one person: the buff nobody asked for, and the courtesy.
mutate("Courtesy.lua",
       "\t\t\t\t\t\tif at then table.remove(queue, at) end\n",
       "",
       "courtesy: somebody who asked is in the queue twice",
       expect=FAVOUR, script=S)

# ------------------------------------------------------------ who and what
# A portal for a passer-by.
mutate("Courtesy.lua",
       "\t\tif not spell or not Known(spell) then return nil, \"off\" end\n\t\tif not inGroup then return nil, \"group\" end\n",
       "\t\tif not spell or not Known(spell) then return nil, \"off\" end\n",
       "courtesy: a portal for somebody outside the group",
       expect=PORTAL, script=S)

# A summon for a passer-by.
mutate("Courtesy.lua",
       "\t\tif not Known(kind.spell) then return nil, \"off\" end\n\t\tif not inGroup then return nil, \"group\" end\n",
       "\t\tif not Known(kind.spell) then return nil, \"off\" end\n",
       "courtesy: a summon for somebody outside the group",
       expect=SUMMON, script=S)

# The rune and the shard are never looked for.
mutate("Courtesy.lua",
       "\tif have ~= 0 then return false end\n",
       "\tif true then return false end\n",
       "courtesy: offered with no reagent in the bags",
       expect=PORTAL, script=S)

# Another spell's cast answers a request for a portal.
mutate("Courtesy.lua",
       "\tif plain(spellId) ~= press.spell then return end\n",
       "",
       "courtesy: any cast answers the portal asked for",
       expect=PORTAL, script=S)

# Whatever the bags hold goes to anybody, whatever their level.
mutate("Courtesy.lua",
       "\tlocal function suits(row) return not (level and row.level) or row.level <= level end\n",
       "\tlocal function suits(row) return true end\n",
       "courtesy: water too high for whoever asked",
       expect=LEVEL, script=S)

# The conjure names no rank: the game casts the best one.
mutate("Courtesy.lua",
       "\t\t\tif type(rank) == \"string\" and rank ~= \"\" then return name .. \"(\" .. rank .. \")\" end\n",
       "",
       "courtesy: the conjure for a low level names no rank",
       expect=LEVEL, script=S)

# "Create Healthstone (Major)" without the empty bracket: read as a rank.
mutate("Courtesy.lua",
       "\tif name:sub(-1) == \")\" then return name .. \"()\" end\n",
       "",
       "courtesy: a name ending in a bracket is cast as a rank",
       expect=STONE, script=S)

# The stone Improved Healthstone makes is not known for one.
mutate("Courtesy.lua",
       "\t{ spell = 11730, level = 48, items = { 9421, 19012, 19013 } },\n",
       "\t{ spell = 11730, level = 48, items = { 9421 } },\n",
       "courtesy: the improved healthstone is not counted",
       expect=STONE, script=S)

# Mists' healthstone traded, as Classic's is.
mutate("Courtesy.lua",
       "\t\t-- the Soulwell.\n\t\thealthstone = { cast = 29893 },\n",
       "\t\t-- the Soulwell.\n\t\thealthstone = { rows = VANILLA_STONES, reagent = SOUL_SHARD },\n",
       "courtesy: mists: a healthstone traded rather than a Soulwell cast",
       expect=WELL, script=S)

# ------------------------------------------------------------ the press
# A trade press casts at them instead.
mutate("Courtesy.lua",
       "\t\tlines[2] = \"/trade\"\n",
       "\t\tlines[2] = \"/cast \" .. text\n",
       "courtesy: the trade press opens no trade",
       expect=WATER, script=S)

# A summon hands the target back, and the portal's click summons nobody.
mutate("Courtesy.lua",
       "\t\tlocal lines, _, record = target(entry, text)\n\t\treturn lines, false, record\n",
       "\t\tlocal lines, restore, record = target(entry, text)\n\t\treturn lines, restore, record\n",
       "courtesy: a summon hands the target back",
       expect=SUMMON, script=S)

# The press is parked for the settle, as if a buff were landing on them.
mutate("Prompt/Press.lua",
       "\tif S.current.courtesy then return ns.Courtesy.Pressed(S.current, S, now) end\n",
       "",
       "courtesy: the press is filed as a buff's",
       expect=WATER, script=S)

# The entry has no name or icon of its own: it is no buff of the sets.
mutate("Core.lua",
       "\tif buff.courtesy then return buff.info end\n",
       "",
       "courtesy: the entry's spell is not named",
       expect=WATER, script=S)

# The reason line is the player's own for a buff asked for.
mutate("Prompt/Paint.lua",
       "\tif entry.courtesy then return ns.Courtesy.Reason(entry) end\n",
       "",
       "courtesy: the reason line does not say what they asked for",
       expect=WATER, script=S)

# The bar macro is handed the trade, a shape it may not hold.
mutate("Prompt/Macro.lua",
       "\t\tif entry.courtesy and entry.courtesy.stage == \"trade\" then S.barText = nil end\n",
       "",
       "courtesy: the bar macro is handed the trade",
       expect=WATER, script=S)

# The tooltip describes a buff cast at them.
mutate("Prompt/Macro.lua",
       "\tif entry.courtesy then return ns.Courtesy.Summary(entry, out) end\n",
       "",
       "courtesy: the tooltip describes a buff",
       expect=TOOLTIP, script=S)

# ------------------------------------------------------------ the trade
# The item goes into a trade with anybody.
mutate("Courtesy.lua",
       "\tif press and GetTime() - press.at <= 20 and Matches(press.request, \"NPC\") then\n",
       "\tif press and GetTime() - press.at <= 20 then\n",
       "courtesy: the item goes into a trade with somebody else",
       expect=STONE, script=S)

# What the cursor held is put in the trade in its place.
mutate("Courtesy.lua",
       "\tif type(_G.GetCursorInfo) == \"function\" and _G.GetCursorInfo() ~= nil then return false end\n",
       "",
       "courtesy: the cursor's own item is taken for the trade",
       expect=STONE, script=S)

# The request still stands once the trade has opened.
mutate("Courtesy.lua",
       "\tServe(request, key)\n\tlocal placed = Place(item)\n",
       "\tlocal placed = Place(item)\n",
       "courtesy: the trade opening does not answer the request",
       expect=WATER, script=S)
