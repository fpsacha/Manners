# The buff order (tests/scenarios/hunt29-order.lua): each fault put back has to
# be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the walk
# The walk goes on in the buff set's order, whatever the player set.
mutate("Core.lua",
       "\tfor _, buff in ipairs(walk) do\n\t\tif ns.IsBuffKnown(buff)\n",
       "\tfor _, buff in ipairs(custom and ns.GetClassBuffs(playerClass) or walk) do\n\t\tif ns.IsBuffKnown(buff)\n",
       "hunt29-order: the walk ignores the order",
       expect="hunt29-order: camelot: a custom order is what a bare warrior, mage and rogue are offered",
       script=S)

# Kings first goes on over an order: the switch is not what the order is.
mutate("Core.lua",
       "\tif custom then strongestFirst = false end\n",
       "",
       "hunt29-order: an order does not switch Kings first off",
       expect="hunt29-order: camelot: an order wins over Kings first, on or off",
       script=S)

# The last blessing a bare person can use is offered, not the first.
mutate("Core.lua",
       "\t\t\t\t\t\telseif not pick then\n\t\t\t\t\t\t\tpick = buff\n",
       "\t\t\t\t\t\telse\n\t\t\t\t\t\t\tpick = buff\n",
       "hunt29-order: the last of the order offered instead of the first",
       expect="hunt29-order: camelot: Greater Blessings follow the order",
       script=S)

# A pin gives way to an order.
mutate("Core.lua",
       "\t\tlocal pinned = ns.PinnedBuff()\n\t\tif pinned then\n\t\t\tif not ns.IsBuffKnown(pinned) then return nil end\n",
       "\t\tlocal pinned = ns.PinnedBuff()\n\t\tif pinned and not ns.HasBuffOrder() then\n\t\t\tif not ns.IsBuffKnown(pinned) then return nil end\n",
       "hunt29-order: a pin gives way to an order",
       expect="hunt29-order: a pinned spell wins over an order",
       script=S)

# ------------------------------------------------ the ordered list
# A buff the order lacks is left out of the walk.
mutate("Core.lua",
       "\t\tfor _, buff in ipairs(base) do\n\t\t\tif not seen[buff.key] then list[#list + 1] = buff end\n\t\tend\n\t\tcache.class",
       "\t\tcache.class",
       "hunt29-order: the buffs an order lacks left out of the walk",
       expect="hunt29-order: the walk reads an order nobody has repaired",
       script=S)

# A key twice in the order is walked twice.
mutate("Core.lua",
       "\t\t\tif buff and not seen[key] then\n\t\t\t\tseen[key] = true\n",
       "\t\t\tif buff then\n\t\t\t\tseen[key] = true\n",
       "hunt29-order: a key twice in the order walked twice",
       expect="hunt29-order: the walk reads an order nobody has repaired",
       script=S)

# The list is kept while the count is the same, whatever the keys: an order
# edited in place is not read again.
mutate("Core.lua",
       "\t\t\t\tif keys[i] ~= order[i] then\n\t\t\t\t\tfresh = false\n\t\t\t\t\tbreak\n\t\t\t\tend\n",
       "\t\t\t\tif false then\n\t\t\t\t\tfresh = false\n\t\t\t\t\tbreak\n\t\t\t\tend\n",
       "hunt29-order: an order edited in place read as it was",
       expect="hunt29-order: the ordered list is read on every scan and rebuilt only when the order changes",
       script=S)

# The list is made again on every scan.
mutate("Core.lua",
       "\t\tif fresh then return cache.list end\n",
       "",
       "hunt29-order: the ordered list rebuilt on every scan",
       expect="hunt29-order: the ordered list is read on every scan and rebuilt only when the order changes",
       script=S)

# ------------------------------------------------ the spell that is named
# The login line and {spell} name Automatic's pick whatever the order says.
mutate("Core.lua",
       "\tlocal walk, custom = ns.WalkBuffs()\n\tif custom then\n\t\tlocal skip = db.buff.skip\n",
       "\tlocal walk, custom = ns.WalkBuffs()\n\tif false then\n\t\tlocal skip = db.buff.skip\n",
       "hunt29-order: the spell named ignores the order",
       expect="hunt29-order: camelot: the spell named for the prompt is the first of the order",
       script=S)

# A spell only a mana user wants named for somebody without mana.
mutate("Core.lua",
       "\t\t\t\tand not (buff.manaOnly and not hasMana) then\n\t\t\t\treturn buff\n",
       "\t\t\t\tthen\n\t\t\t\treturn buff\n",
       "hunt29-order: a mana-only spell named for somebody without mana",
       expect="hunt29-order: camelot: the spell named for the prompt is the first of the order",
       script=S)

# A switched-off spell named.
mutate("Core.lua",
       "\t\t\tif ns.IsBuffKnown(buff) and not buff.neverAuto and not (skip and skip[buff.key])\n\t\t\t\tand not (buff.manaOnly",
       "\t\t\tif ns.IsBuffKnown(buff) and not buff.neverAuto\n\t\t\t\tand not (buff.manaOnly",
       "hunt29-order: a switched-off spell named from the order",
       expect="hunt29-order: camelot: the spell named for the prompt is the first of the order",
       script=S)

# ------------------------------------------------ the repair
# Nothing repaired at load.
mutate("Core.lua",
       "\tfor class, keys in pairs(order) do\n\t\tlocal repaired = type(class)",
       "\tfor class, keys in pairs({}) do\n\t\tlocal repaired = type(class)",
       "hunt29-order: a damaged order not repaired",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# The order table itself, not a table, left as it is.
mutate("Core.lua",
       "\tif type(order) ~= \"table\" then\n\t\tfixed(\"buff.order\", order)\n\t\torder = {}\n\t\tprofile.buff.order = order\n\tend\n",
       "",
       "hunt29-order: a damaged order table not replaced",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# A key no client has kept.
mutate("Core.lua",
       "\t\t\tif type(key) == \"string\" and known[key] and not seen[key] then\n",
       "\t\t\tif type(key) == \"string\" and not seen[key] then\n",
       "hunt29-order: a key no client has kept",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# A key twice kept.
mutate("Core.lua",
       "\t\t\tif type(key) == \"string\" and known[key] and not seen[key] then\n",
       "\t\t\tif type(key) == \"string\" and known[key] then\n",
       "hunt29-order: a key twice kept",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# A key only another client has dropped from the profile.
mutate("Core.lua",
       "\t\t\tif type(key) == \"string\" and known[key] and not seen[key] then\n",
       "\t\t\tif type(key) == \"string\" and known[key] and not seen[key] and ns.FindBuff(class, key) then\n",
       "hunt29-order: another client's key dropped",
       expect="hunt29-order: an order saved on another client keeps its keys and skips the ones this client lacks",
       script=S)

# No client's keys known but this one's.
mutate("Buffs.lua",
       "for _, set in pairs(SETS) do\n\tfor class, list in pairs(set.buffs or {}) do\n",
       "for _, set in pairs({ camelot = SETS.camelot, mists = SETS.mists }) do\n\tfor class, list in pairs(set.buffs or {}) do\n",
       "hunt29-order: Classic Era's keys not known to the repair",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# The buffs an order lacks are not put after it.
mutate("Core.lua",
       "\t\tfor _, buff in ipairs(Automatic(class, kingsFirst)) do\n\t\t\tif not seen[buff.key] then out[#out + 1] = buff.key end\n\t\tend\n\t\treturn out\n",
       "\t\treturn out\n",
       "hunt29-order: the buffs an order lacks not added",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# The buffs an order lacks added in the set's order, Kings first or not.
mutate("Core.lua",
       "\t\tfor _, buff in ipairs(Automatic(class, kingsFirst)) do\n\t\t\tif not seen[buff.key] then out[#out + 1] = buff.key end\n",
       "\t\tfor _, buff in ipairs(Automatic(class, false)) do\n\t\t\tif not seen[buff.key] then out[#out + 1] = buff.key end\n",
       "hunt29-order: the buffs an order lacks added without Kings first",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# An order with nothing left in it is kept, as the whole of Automatic's.
mutate("Core.lua",
       "\t\tif #out == 0 then return nil end\n",
       "",
       "hunt29-order: an order with nothing left kept",
       expect="hunt29-order: a damaged order is repaired",
       script=S)

# ------------------------------------------------ moving one
# Up at the top goes round to the bottom.
mutate("Core.lua",
       "\t\tlocal to = rank and here[rank + step]\n",
       "\t\tlocal to = rank and here[(rank + step - 1) % #here + 1]\n",
       "hunt29-order: the top moves up to the bottom",
       expect="hunt29-order: camelot: up at the top and down at the bottom do nothing",
       script=S)

# An order that is Automatic's is kept.
mutate("Core.lua",
       "\t\tdb.buff.order[playerClass] = (not same) and keys or nil\n",
       "\t\tdb.buff.order[playerClass] = keys\n",
       "hunt29-order: an order that is Automatic's kept",
       expect="hunt29-order: camelot: a move swaps two places and an order that is Automatic's is not kept",
       script=S)

# A move starts from Automatic with Kings first, whatever the switch.
mutate("Core.lua",
       "\t\tfor i, buff in ipairs(Automatic(playerClass, kingsFirst)) do auto[i] = buff.key end\n",
       "\t\tfor i, buff in ipairs(Automatic(playerClass, true)) do auto[i] = buff.key end\n",
       "hunt29-order: a move starts from Kings first whatever the switch",
       expect="hunt29-order: camelot: a move swaps two places and an order that is Automatic's is not kept (Kings first off)",
       script=S)

# A move among every key, the ones this client lacks too.
mutate("Core.lua",
       "\t\t\tif has[k] then here[#here + 1] = i end\n",
       "\t\t\there[#here + 1] = i\n",
       "hunt29-order: a move among the keys this client lacks",
       expect="hunt29-order: an order saved on another client keeps its keys and skips the ones this client lacks",
       script=S)

# Back to Automatic leaves the order.
mutate("Core.lua",
       "\t\tdb.buff.order[playerClass] = nil\n\t\treturn true\n",
       "\t\treturn true\n",
       "hunt29-order: Back to Automatic leaves the order",
       expect="hunt29-order: camelot: Back to Automatic restores the walk exactly",
       script=S)

# No order is ever read as one.
mutate("Core.lua",
       "\t\treturn ns.BuffOrder() ~= nil\n",
       "\t\treturn false\n",
       "hunt29-order: an order never read as one",
       expect="hunt29-order: camelot: the Kings switch is hidden while an order stands and comes back",
       script=S)

# The page lists Automatic without Kings first.
mutate("Core.lua",
       "\t\tif not custom then return Automatic(playerClass, db ~= nil and db.buff.kingsFirst == true) end\n",
       "\t\tif not custom then return Automatic(playerClass, false) end\n",
       "hunt29-order: the page lists Automatic without Kings first",
       expect="hunt29-order: the old dialog's dropdown and buttons move the picked buff",
       script=S)

# ------------------------------------------------ the setting
# No default for the classes to keep an order in.
mutate("Core.lua",
       "\t\t\torder = {},\n\t\t},\n\n\t\tsources = {",
       "\t\t},\n\n\t\tsources = {",
       "hunt29-order: no default for the order",
       expect="hunt29-order: a new profile has no order, and the default is a table for the classes",
       script=S)

# Left out of the page's reset.
mutate("Options/Advanced.lua",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.kingsFirst\", \"buff.order\", \"filters.relevantOnly\",\n",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.kingsFirst\", \"filters.relevantOnly\",\n",
       "hunt29-order: the page's reset leaves the order",
       expect="hunt29-order: the page's reset takes the order away",
       script=S)

# ------------------------------------------------ the controls
# Shown to a class with one buff.
mutate("Options/Who.lua",
       "\treturn ns.PinnedBuff() ~= nil or #(ns.GetClassBuffs(ns.caps.class) or {}) < 2\n",
       "\treturn ns.PinnedBuff() ~= nil\n",
       "hunt29-order: the order shown to a class with one buff",
       expect="hunt29-order: the controls are not shown to a class with one buff",
       script=S)

# Shown over a pin, which is all that is considered then.
mutate("Options/Who.lua",
       "\treturn ns.PinnedBuff() ~= nil or #(ns.GetClassBuffs(ns.caps.class) or {}) < 2\n",
       "\treturn #(ns.GetClassBuffs(ns.caps.class) or {}) < 2\n",
       "hunt29-order: the order shown over a pin",
       expect="hunt29-order: the controls are for a class with a choice and no spell pinned",
       script=S)

# The way back shown before anything is moved.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return OrderHidden() or not ns.HasBuffOrder() end,\n",
       "\t\t\t\thidden = OrderHidden,\n",
       "hunt29-order: Back to Automatic shown over Automatic",
       expect="hunt29-order: the controls are for a class with a choice and no spell pinned",
       script=S)

# The Kings switch shown over an order.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil or ns.HasBuffOrder() end,\n",
       "\t\t\t\thidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil end,\n",
       "hunt29-order: the Kings switch shown over an order",
       expect="hunt29-order: camelot: the Kings switch is hidden while an order stands and comes back",
       script=S)

# Move up live on the first buff.
mutate("Options/Who.lua",
       "\t\t\t\tdisabled = function() return OrderRank(OrderPick()) <= 1 end,\n",
       "\t\t\t\tdisabled = function() return false end,\n",
       "hunt29-order: Move up live on the first buff",
       expect="hunt29-order: camelot: up at the top and down at the bottom do nothing",
       script=S)

# Move down live on the last buff.
mutate("Options/Who.lua",
       "\t\t\t\t\treturn rank == 0 or rank >= #OrderKeys()\n",
       "\t\t\t\t\treturn rank == 0\n",
       "hunt29-order: Move down live on the last buff",
       expect="hunt29-order: camelot: up at the top and down at the bottom do nothing",
       script=S)

# The one moved does not stay picked.
mutate("Options/Who.lua",
       "\t\torderPicked = key\n\t\trestyleAndMacro()\n",
       "\t\torderPicked = nil\n\t\trestyleAndMacro()\n",
       "hunt29-order: the buff moved not kept picked",
       expect="hunt29-order: the old dialog's dropdown and buttons move the picked buff",
       script=S)

# The dialog not redrawn after a move.
mutate("Options/Who.lua",
       "\t\torderPicked = key\n\t\trestyleAndMacro()\n\t\tns.RefreshOptionsDisplay()\n",
       "\t\torderPicked = key\n\t\trestyleAndMacro()\n",
       "hunt29-order: the dialog not redrawn after a move",
       expect="hunt29-order: the old dialog's dropdown and buttons move the picked buff",
       script=S)

# The prompt not told after the way back.
mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.ClearBuffOrder() then\n\t\t\t\t\t\trestyleAndMacro()\n",
       "\t\t\t\t\tif ns.ClearBuffOrder() then\n",
       "hunt29-order: the prompt not told after Back to Automatic",
       expect="hunt29-order: the old dialog's dropdown and buttons move the picked buff",
       script=S)

# The dropdown sorted by name, not in the order.
mutate("Options/Who.lua",
       "\t\t\t\tvalues = OrderChoices,\n\t\t\t\tsorting = OrderKeys,\n",
       "\t\t\t\tvalues = OrderChoices,\n",
       "hunt29-order: the list sorted by name",
       expect="hunt29-order: camelot: the window draws a line for each buff, in order",
       script=S)

# Not placed in the window: a setting nobody can reach there.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t{ key = \"who.order\", header = \"who.orderHeader\", items = {\n"
       "\t\t\t\t\t{ composite = \"order\", ids = {\n"
       "\t\t\t\t\t\t\"who.orderNote\", \"who.orderPick\", \"who.orderUp\", \"who.orderDown\", \"who.orderReset\",\n"
       "\t\t\t\t\t} },\n"
       "\t\t\t\t} },\n",
       "",
       "hunt29-order: the controls not placed in the window",
       expect="every control has one place in the options window",
       script=S)

# ------------------------------------------------ the window
# A greyed arrow up on no line.
mutate("Options/Window/WidgetsOrder.lua",
       "\tline.up:SetEnabled(rank > 1)\n",
       "\tline.up:SetEnabled(true)\n",
       "hunt29-order: window: an arrow up on the first line",
       expect="hunt29-order: window: no arrow up on the first line and none down on the last",
       script=S)

mutate("Options/Window/WidgetsOrder.lua",
       "\tline.down:SetEnabled(rank < last)\n",
       "\tline.down:SetEnabled(true)\n",
       "hunt29-order: window: an arrow down on the last line",
       expect="hunt29-order: window: no arrow up on the first line and none down on the last",
       script=S)

# Every line set apart.
mutate("Options/Window/WidgetsOrder.lua",
       "\tline.wash:SetShown(first)\n",
       "\tline.wash:SetShown(true)\n",
       "hunt29-order: window: every line set apart",
       expect="hunt29-order: window: the first line the walk can use is set apart, the others are not",
       script=S)

# The first line set apart, learned or not.
mutate("Options/Window/WidgetsOrder.lua",
       "\t\t\tif usable[v[1]] then\n\t\t\t\tfirst = v[1]\n",
       "\t\t\tif true then\n\t\t\t\tfirst = v[1]\n",
       "hunt29-order: window: the first line set apart though not learned",
       expect="hunt29-order: window: the first line the walk can use is set apart, the others are not",
       script=S)

# A buff not learned drawn in full colour.
mutate("Options/Window/WidgetsOrder.lua",
       "\tline.icon:SetDesaturated(not usable)\n",
       "\tline.icon:SetDesaturated(false)\n",
       "hunt29-order: window: a buff not learned drawn in full colour",
       expect="hunt29-order: window: the first line the walk can use is set apart, the others are not",
       script=S)

# The place of each line.
mutate("Options/Window/WidgetsOrder.lua",
       "\tline.num:SetText(tostring(rank))\n",
       "\tline.num:SetText(tostring(rank - 1))\n",
       "hunt29-order: window: the lines numbered from nought",
       expect="hunt29-order: camelot: the window draws a line for each buff, in order",
       script=S)

# The same icon on every line.
mutate("Options/Window/WidgetsOrder.lua",
       "\tline.icon:SetTexture(IconOf(key))\n",
       "\tline.icon:SetTexture(UNKNOWN_ICON)\n",
       "hunt29-order: window: the same icon on every line",
       expect="hunt29-order: camelot: the window draws a line for each buff, in order",
       script=S)

# The way back shown always.
mutate("Options/Window/WidgetsOrder.lua",
       "\t\tlocal resetShown = row.reset ~= nil and not Bind().Hidden(row.reset.item)\n",
       "\t\tlocal resetShown = row.reset ~= nil\n",
       "hunt29-order: window: Back to Automatic shown always",
       expect="hunt29-order: window: Back to Automatic is there only while the order differs",
       script=S)

# An arrow that does nothing.
mutate("Options/Window/WidgetsOrder.lua",
       "\tBind().Run(part)\n",
       "",
       "hunt29-order: window: an arrow does nothing",
       expect="hunt29-order: window: a press repaints the list and the page at once",
       script=S)

# An arrow that moves the buff and does not tell the window.
mutate("Options/Window/WidgetsOrder.lua",
       "\tBind().Run(part)\n",
       "\tns.MoveBuff(key, b.step)\n",
       "hunt29-order: window: an arrow that does not tell the window",
       expect="hunt29-order: window: a press repaints the list and the page at once",
       script=S)

# The buff that moved not lit.
mutate("Options/Window/WidgetsOrder.lua",
       "\tif moved then Flash(line) end\n",
       "",
       "hunt29-order: window: the buff that moved not lit",
       expect="hunt29-order: window: a press repaints the list and the page at once",
       script=S)
