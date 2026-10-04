# The buff data held to WoW Forever's own spell tables: each fix put back,
# and required to be caught by its scenario in tests/scenarios/data-audit.lua
# (or the file the scenario it touched lives in).
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ a group spell reaches the raid
mutate("GroupBuffs.lua",
       "\t\t\t\twhere = ns.GROUP_IS_RAID and \"raid\" or RaidSubgroup(entry.unit, memo)\n",
       "\t\t\t\twhere = RaidSubgroup(entry.unit, memo)\n",
       "data-audit: Forever's raid counted by raid group",
       expect="data-audit: on Forever one group spell covers everybody in the raid", script=S)
mutate("Buffs.lua",
       "local CAMELOT_SET = setmetatable({ buffs = CAMELOT, own = CAMELOT_OWN, groupIsRaid = true },\n",
       "local CAMELOT_SET = setmetatable({ buffs = CAMELOT, own = CAMELOT_OWN },\n",
       "data-audit: Forever's set not raid-wide",
       expect="data-audit: on Forever a raider flagged in any raid group holds the group cast back", script=S)
mutate("GroupBuffs.lua",
       "\telseif inRaid and bucket.where == \"raid\" then\n\t\treturn L[\"Your raid\"], L[\"your raid\"]\n",
       "",
       "data-audit: a raid-wide cast named as a party",
       expect="the panel calls a cast that covers the raid", script=S)
mutate("GroupBuffs.lua",
       "\tif ns.GROUP_IS_RAID then\n\t\tlocal slider = L[",
       "\tif false then\n\t\tlocal slider = L[",
       "data-audit: Forever's settings say one party",
       expect="data-audit: the group buff settings say what one cast counts (Forever)", script=S)
mutate("GroupBuffs.lua",
       "\tif ns.GROUP_IS_RAID then\n\t\tlocal slider = L[",
       "\tif true then\n\t\tlocal slider = L[",
       "data-audit: Classic Era's settings say the raid",
       expect="data-audit: the group buff settings say what one cast counts (Classic Era)", script=S)
mutate("Options/Start.lua",
       "\t\t\t\tlocal raidWide = ns.GROUP_IS_RAID and not ns.GROUP_BY_CLASS[ns.PlayerClass()]\n",
       "\t\t\t\tlocal raidWide = false\n",
       "data-audit: Start here says one party on Forever",
       expect="the group buffs and their reagent are not said", script=S)

# ------------------------------------------------ Prayer of Fortitude's candle
mutate("Buffs.lua",
       "{ id = 21562, reagent = HOLY_CANDLE }",
       "{ id = 21562, reagent = SACRED_CANDLE }",
       "data-audit: Prayer of Fortitude rank 1 on Sacred Candles",
       expect="data-audit: Prayer of Fortitude's first rank takes a Holy Candle (first rank, Holy Candles)", script=S)

# ------------------------------------------------ Omen of Clarity
mutate("Buffs.lua",
       "\t\t\tif family.key ~= \"omen\" then list[#list + 1] = family end\n",
       "\t\t\tlist[#list + 1] = family\n",
       "data-audit: Omen of Clarity offered on Forever",
       expect="data-audit: Omen of Clarity is a druid's own buff only on Classic Era (Forever)", script=S)
mutate("Buffs.lua",
       "\t\t{ key = \"omen\", spells = { { key = \"omen\", ranks = { 16864 }, talent = true } } },\n",
       "",
       "data-audit: Omen of Clarity gone from Classic Era too",
       expect="data-audit: Omen of Clarity is a druid's own buff only on Classic Era (Classic Era)", script=S)

# ------------------------------------------------ Kings and Divine Spirit are trained
mutate("Buffs.lua",
       "\tlocal TRAINED = { kings = true, spirit = true }\n",
       "\tlocal TRAINED = { spirit = true }\n",
       "data-audit: Kings a talent on Forever",
       expect="data-audit: Skip my own class skips a paladin who trains Kings on Forever", script=S)
mutate("Buffs.lua",
       "\tlocal TRAINED = { kings = true, spirit = true }\n",
       "\tlocal TRAINED = { kings = true }\n",
       "data-audit: Divine Spirit a talent on Forever",
       expect="data-audit: Skip my own class skips a priest who trains Divine Spirit on Forever", script=S)
mutate("Buffs.lua",
       "\t[20217] = 20, [14752] = 30, [14818] = 40, [14819] = 50, [27841] = 60,\n",
       "\t[20217] = 20,\n",
       "data-audit: Divine Spirit has no rank levels",
       expect="data-audit: Skip my own class skips a priest who trains Divine Spirit on Forever", script=S)
mutate("Buffs.lua",
       "\t[20217] = 20, [14752] = 30, [14818] = 40, [14819] = 50, [27841] = 60,\n",
       "\t[14752] = 30, [14818] = 40, [14819] = 50, [27841] = 60,\n",
       "data-audit: Kings has no rank level",
       expect="data-audit: Skip my own class skips a paladin who trains Kings on Forever", script=S)

# ------------------------------------------------ Blessing of Sanctuary is gone
mutate("Buffs.lua",
       "\tlocal GONE = { sanctuary = true }\n",
       "\tlocal GONE = {}\n",
       "data-audit: Sanctuary listed on Forever",
       expect="data-audit: a Forever paladin has no Blessing of Sanctuary to call unknown", script=S)
mutate("Buffs.lua",
       "local CAMELOT_SET = setmetatable({ buffs = CAMELOT, own = CAMELOT_OWN, groupIsRaid = true },\n",
       "local CAMELOT_SET = setmetatable({ own = CAMELOT_OWN, groupIsRaid = true },\n",
       "data-audit: Forever given the vanilla buffs whole",
       expect="data-audit: a Forever paladin has no Blessing of Sanctuary to call unknown", script=S)

# ------------------------------------------------ Salvation reaches your group only
mutate("Buffs.lua",
       "\t\t\tgroupOnly = true,\n\t\t\tgroupCast = Greater(25895),\n",
       "\t\t\tgroupCast = Greater(25895),\n",
       "data-audit: Salvation offered to anybody",
       expect="data-audit: Salvation is offered only to your party or raid", script=S)
mutate("Core.lua",
       "\t\tif buff.groupOnly and not (opts.inGroup or opts.inParty) then return false end\n",
       "",
       "data-audit: groupOnly never asked",
       expect="data-audit: a passer-by wearing another paladin's Might and Kings is offered Light", script=S)
mutate("Core.lua",
       "\t\tif buff.groupOnly and not (opts.inGroup or opts.inParty) then return false end\n",
       "\t\tif buff.groupOnly and not opts.inParty then return false end\n",
       "data-audit: groupOnly read as your subgroup",
       expect="data-audit: Salvation reaches a raider in another raid group", script=S)
mutate("Core.lua",
       "\t\tif not (buff.partyOnly or buff.groupOnly) then return false end\n",
       "\t\tif not buff.partyOnly then return false end\n",
       "data-audit: Salvation alone reads as reaching passers-by",
       expect="with Salvation pinned, People who buff me does not say it reaches your group", script=S)
mutate("Core.lua",
       "\t\tif buff.groupOnly and not buff.partyOnly then return false end\n",
       "",
       "data-audit: Salvation said to reach only your subgroup",
       expect="with Salvation pinned, People who buff me does not say it reaches your group", script=S)
mutate("Options/Who.lua",
       "\tif buff.partyOnly or buff.groupOnly then label = L[",
       "\tif buff.partyOnly then label = L[",
       "data-audit: Salvation's switch not marked group only",
       expect="Who to buff does not say Salvation reaches your group only", script=S)

# ------------------------------------------------ favours Manners never offers
mutate("Buffs.lua",
       "\tfavourOnly = { 6346, 546, 11743, 2970, 132, 20765, 20764, 20763, 20762, 20707 },\n",
       "\tfavourOnly = {},\n",
       "data-audit: a Fear Ward is no favour",
       expect="data-audit: a Fear Ward or a Soulstone from somebody is a favour", script=S)
mutate("Buffs.lua",
       "\tns.FAVOUR_ONLY_IDS = chosen.favourOnly\n",
       "",
       "data-audit: the favour-only ids never read",
       expect="data-audit: a Fear Ward or a Soulstone from somebody is a favour", script=S)
mutate("Buffs.lua",
       "\t\tns.ALL_BUFF_IDS[id] = true\n\tend\nend\n",
       "\t\tns.ALL_BUFF_IDS[id] = true\n\t\tns.BUFF_BY_ID[id] = (ns.BUFFS.MAGE or {})[1]\n\tend\nend\n",
       "data-audit: a Fear Ward filed under a buff",
       expect="Fear Ward or a Soulstone is filed under a buff Manners offers", script=S)

# ------------------------------------------------ Water Breathing
mutate("Buffs.lua",
       "\t\t\tgroup = { 131 },\n",
       "",
       "data-audit: Water Breathing not Unending Breath",
       expect="data-audit: somebody breathing water from a shaman is not offered Unending Breath", script=S)

# ------------------------------------------------ ub
mutate("Requests.lua",
       "\"water breathing\", \"ub\", \"~breath\" },\n",
       "\"water breathing\", \"~breath\" },\n",
       "data-audit: ub not heard",
       expect="data-audit: ub asks a warlock for Unending Breath", script=S)
