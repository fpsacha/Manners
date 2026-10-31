# Hunt 41, the leftovers (Core.lua, Prompt/Text.lua, Buffs.lua, Queue.lua,
# Options/Look.lua, Options/Window/Window.lua): the yes/no settings of the
# wrong type, the prompt's text fitted again on every repaint, Sanctuary's
# ranks without a level, a blessing out of mana not read for coverage, the
# fallback dialog's words for Panel style, and the picker repainted by the
# probe. Each fault is caught by the scenario in
# tests/scenarios/hunt41-leftovers.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "hunt41-leftovers: "

# ------------------------------------------------ 1: the types of the settings

# The pass that puts the rest right does nothing.
mutate("Core.lua",
       "\t\t\t\tif type(value) ~= leaf[3] or value ~= value then\n",
       "\t\t\t\tif false then\n",
       "hunt41-leftovers: no setting is checked for its type",
       expect=P + "every yes/no setting of the wrong type goes back to its default", script=S)

# Every yes/no it has not already repaired is let through.
mutate("Core.lua",
       "\t\t\t\tif type(value) ~= leaf[3] or value ~= value then\n",
       "\t\t\t\tif leaf[3] ~= \"boolean\" and (type(value) ~= leaf[3] or value ~= value) then\n",
       "hunt41-leftovers: a yes/no of the wrong type is let through",
       expect=P + "every yes/no setting of the wrong type goes back to its default", script=S)

# Text and numbers are not part of the walk.
mutate("Core.lua",
       "\t\t\t\tif type(k) == \"string\" and (kind == \"boolean\" or kind == \"number\" or kind == \"string\") then\n",
       "\t\t\t\tif type(k) == \"string\" and kind == \"boolean\" then\n",
       "hunt41-leftovers: a text or a number of the wrong type is let through",
       expect=P + "a string or number setting of the wrong type goes back to its default", script=S)

# Every value is put back, valid or not.
mutate("Core.lua",
       "\t\t\t\tif type(value) ~= leaf[3] or value ~= value then\n",
       "\t\t\t\tif true then\n",
       "hunt41-leftovers: a valid setting is put back to its default",
       expect=P + "the repair keeps a valid yes/no, either way, and repeats to the same", script=S)

# ------------------------------------------------ 2: the fitted line

KEY = "\tif memo and memo.text == text and memo.room == room and memo.base == base\n"
KEY2 = "\t\tand memo.path == path and memo.flags == fit.flags then\n"
FREE = P + "an unchanged line that had to shrink costs no font call on a repaint"

# Every repaint measures again.
mutate("Prompt/Text.lua", KEY, "\tif false and memo and memo.text == text and memo.room == room and memo.base == base\n",
       "hunt41-leftovers: a line is fitted again on every repaint", expect=FREE, script=S)

# The text is not part of the key: a short line is taken for the long one.
mutate("Prompt/Text.lua", KEY, "\tif memo and memo.room == room and memo.base == base\n",
       "hunt41-leftovers: the fit does not depend on the text", expect=FREE, script=S)

# The room is not part of the key.
mutate("Prompt/Text.lua", KEY, "\tif memo and memo.text == text and memo.base == base\n",
       "hunt41-leftovers: the fit does not depend on the room", expect=FREE, script=S)

# The base size is not part of the key.
mutate("Prompt/Text.lua", KEY, "\tif memo and memo.text == text and memo.room == room\n",
       "hunt41-leftovers: the fit does not depend on the base size", expect=FREE, script=S)

# The face is not part of the key.
mutate("Prompt/Text.lua", KEY2, "\t\tand memo.flags == fit.flags then\n",
       "hunt41-leftovers: the fit does not depend on the face", expect=FREE, script=S)

# The outline is not part of the key.
mutate("Prompt/Text.lua", KEY2, "\t\tand memo.path == path then\n",
       "hunt41-leftovers: the fit does not depend on the outline", expect=FREE, script=S)

# A remembered fit leaves the font where it was, whatever size it was at.
mutate("Prompt/Text.lua",
       "\t\tif fit.size[fs] ~= memo.size then\n",
       "\t\tif false then\n",
       "hunt41-leftovers: a remembered fit leaves the font where it was", expect=FREE, script=S)

# ------------------------------------------------ 3: Sanctuary's levels

mutate("Buffs.lua",
       "\t[20911] = 30, [20912] = 40, [20913] = 50, [20914] = 60,\n",
       "",
       "hunt41-leftovers: Sanctuary's ranks have no level",
       expect=P + "vanilla: a weak worn Sanctuary rank is not the one your cast would land", script=S)

mutate("Buffs.lua",
       "\t[27168] = 70,\n}) do\n",
       "}) do\n",
       "hunt41-leftovers: Burning Crusade's Sanctuary has no level",
       expect=P + "tbc: a weak worn Sanctuary rank is not the one your cast would land", script=S)

mutate("Buffs.lua",
       "\t[20911] = 30, [20912] = 40, [20913] = 50, [20914] = 60,\n",
       "\t[20911] = 30, [20912] = 40, [20913] = 50, [20914] = 59,\n",
       "hunt41-leftovers: Sanctuary's fourth rank learned at 59",
       expect="tbc: every rank is learned at the level the client trains it", script=S)

# ------------------------------------------------ 4: a blessing out of mana

# What the walk is handed is never read.
mutate("Core.lua",
       "\t\t\tif not pinned and not opts.asked and unpaid then\n",
       "\t\t\tif false and unpaid then\n",
       "hunt41-leftovers: a blessing out of mana is not read for coverage",
       expect=P + "camelot: his Kings on somebody, out of mana for it, is left alone", script=S)

# Read even for somebody who asked for another blessing by name.
mutate("Core.lua",
       "\t\t\tif not pinned and not opts.asked and unpaid then\n",
       "\t\t\tif not pinned and unpaid then\n",
       "hunt41-leftovers: a request by name is held off by a blessing out of mana",
       expect=P + "camelot: somebody who asks for Might by name is offered it over his Kings", script=S)

# Read even under a pin.
mutate("Core.lua",
       "\t\t\tif not pinned and not opts.asked and unpaid then\n",
       "\t\t\tif not opts.asked and unpaid then\n",
       "hunt41-leftovers: a pin is held off by a blessing out of mana",
       expect=P + "camelot: a pin on Might is offered over his Kings, which a pin replaces as ever", script=S)

# Another paladin's Kings counts as ours.
mutate("Core.lua",
       "\t\t\t\t\tlocal held, _, mine = has(unpaid[i], opts)\n\t\t\t\t\tif held == true and mine ~= false then return nil, true end\n",
       "\t\t\t\t\tlocal held, _, mine = has(unpaid[i], opts)\n\t\t\t\t\tif held == true then return nil, true end\n",
       "hunt41-leftovers: another paladin's blessing out of mana covers them",
       expect=P + "camelot: another paladin's Kings is no reason to leave them", script=S)

# Affordable keeps no list of what it left out.
mutate("Queue.lua",
       "\t\telseif unpaid then\n\t\t\tunpaid[#unpaid + 1] = buff\n",
       "\t\telseif unpaid then\n\t\t\tlocal _ = buff\n",
       "hunt41-leftovers: the buffs left out for want of mana are not kept",
       expect=P + "camelot: his Kings on somebody, out of mana for it, is left alone", script=S)

# The scan's walk is not handed the list.
mutate("Queue.lua",
       "\tlocal opts = { unpaid = UNPAID }\n",
       "\tlocal opts = {}\n",
       "hunt41-leftovers: the queue's walk is not told what was left out",
       expect=P + "vanilla: his Kings on somebody, out of mana for it, is left alone", script=S)

# Your own walk is not handed it.
mutate("Queue.lua",
       "\t\tunpaid = UNPAID,\n\t\tnow = now,\n",
       "\t\tnow = now,\n",
       "hunt41-leftovers: your own walk is not told what was left out",
       expect=P + "camelot: your own Kings on you, out of mana for it, is left alone", script=S)

# ------------------------------------------------ 5: Panel style's words

mutate("Options/Look.lua",
       "\t\t\t\tdesc = L[\"Pick a theme for the prompt from the list. It switches at once.\"],\n",
       "\t\t\t\tdesc = L[\"Pick a theme for the prompt. Click a card to switch to it at once.\"],\n",
       "hunt41-leftovers: the dropdown's help tells you to click a card",
       expect=P + "Panel style's description fits the dropdown the fallback dialog draws", script=S)

mutate("Options/Look.lua",
       "\t\t\t\tdesc = L[\"Pick a theme for the prompt from the list. It switches at once.\"],\n",
       "\t\t\t\tdesc = L[\"Pick a look for the prompt from the list. It switches at once.\"],\n",
       "hunt41-leftovers: the dropdown's help no longer says theme",
       expect=P + "Panel style's description fits the dropdown the fallback dialog draws", script=S)

# ------------------------------------------------ 6: the picker after SPELLS_CHANGED

mutate("Options/Window/Window.lua",
       "\t\t\tif UI.Shown() then ns.Guard(\"options repaint\", UI.Refresh) end\n",
       "",
       "hunt41-leftovers: the open window is not repainted after the probe",
       expect=P + "a spellbook change puts the loaded icon on the open picker's cards", script=S)

# ------------------------------------------------ 7: a restyle with the count up

# The restyle of the three built-in looks hides the chip and the count and
# leaves the repaint that brings them back to the next scan.
mutate("Prompt/Panel.lua",
       "\tR.queueHair:SetVertexColor(1, 1, 1, 0.07)\n\n\tself:Refresh()\nend\n",
       "\tR.queueHair:SetVertexColor(1, 1, 1, 0.07)\nend\n",
       "hunt41-leftovers: a restyle of a built-in look repaints nobody",
       expect=P + "glass: a restyle with the count chip up brings the count back", script=S)

# The same for a look from Looks/.
mutate("Prompt/Panel.lua",
       "\tself:SyncCooldown()\n\tself:Refresh()\nend\n",
       "\tself:SyncCooldown()\nend\n",
       "hunt41-leftovers: a restyle of a look from Looks/ repaints nobody",
       expect=P + "luxe: a restyle with the count chip up brings the count back", script=S)

# The width FitLine measured is not kept when it first measures a line: the
# looks measure it again themselves, for every restyle.
mutate("Prompt/Text.lua",
       "\tfit.drawn[fs] = w\n",
       "",
       "hunt41-leftovers: FitLine keeps no measured width on the first fit",
       expect="hunt38-picker: switching glass -> framed -> glass", script=S)
