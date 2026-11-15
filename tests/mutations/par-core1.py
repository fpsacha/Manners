# Mutations for tests/scenarios/par-core1.lua (the weakest-point review of
# 2026-11-15): each undoes one of its three fixes, or breaks what a fix has to
# keep, and names the scenario that must catch it.

S = "runscenarios.py"

# ------------------------------------------------ 1. who walked off

# The order inside a tier without the range: the current pick, only
# remembered, keeps the prompt on the tie against somebody in reach.
mutate("Prompt/Hold.lua",
       "\tif aReach ~= bReach then return aReach > bReach end\n",
       "",
       "par-core1: the tie keeps a passer-by who walked off",
       expect="par-core1: a passer-by who walked off gives way to one still in reach", script=S)

# The hold keeps them instead: the queue's own entry, unmeasured, held over
# somebody measured in reach.
mutate("Prompt/Hold.lua",
       "\tif held ~= S.heldEntry and top.priority == held.priority and Reach(top) < Reach(held)\n",
       "\tif false and held ~= S.heldEntry and top.priority == held.priority and Reach(top) < Reach(held)\n",
       "par-core1: the hold keeps a passer-by who walked off",
       expect="par-core1: a passer-by who walked off gives way to one still in reach", script=S)

# The range read over the cursor: 1.1.1's hold, somebody the mouse is reaching
# for, lost to whoever is in reach.
mutate("Prompt/Hold.lua",
       "\t\tand not CursorHolds(S.heldEntry, GetTime()) then\n",
       "\t\tthen\n",
       "par-core1: the range beats the cursor",
       expect="par-core1: the cursor on the panel keeps a passer-by who walked off", script=S)

# ------------------------------------------------ 2. where they stand

# Line of sight read as about the person again.
mutate("Queue.lua",
       "\tlocal WHERE = { \"SPELL_FAILED_LINE_OF_SIGHT\", \"ERR_OUT_OF_RANGE\", \"SPELL_FAILED_OUT_OF_RANGE\" }\n",
       "\tlocal WHERE = { \"ERR_OUT_OF_RANGE\", \"SPELL_FAILED_OUT_OF_RANGE\" }\n",
       "par-core1: out of sight backs off like the person",
       expect="par-core1: refused SPELL_FAILED_LINE_OF_SIGHT three times", script=S)

# Every refusal on the person's run, where they stand or not.
mutate("Queue.lua",
       "\t\tif OneOf(why, WHERE) then\n\t\t\tr.undo = nil\n",
       "\t\tif false then\n\t\t\tr.undo = nil\n",
       "par-core1: where they stand is a step of the person's run",
       expect="back within half a minute", script=S)

# Where they stand climbing to five minutes after all.
mutate("Queue.lua",
       "\tlocal WHERE_STEPS = { 5, 15, 30 }\n",
       "\tlocal WHERE_STEPS = { 5, 30, 300 }\n",
       "par-core1: where they stand backs off for minutes",
       expect="three times, back within half a minute", script=S)

# Straight back after two seconds, to be refused again.
mutate("Queue.lua",
       "\tlocal WHERE_STEPS = { 5, 15, 30 }\n",
       "\tlocal WHERE_STEPS = { 2, 15, 30 }\n",
       "par-core1: out of sight back after two seconds",
       expect="par-core1: refused SPELL_FAILED_LINE_OF_SIGHT three times", script=S)

# The error line that comes a moment late only names the reason.
mutate("Queue.lua",
       "\t\t\tif undo and undo.at == r.last and OneOf(message, WHERE) then\n",
       "\t\t\tif false then\n",
       "par-core1: out of sight said late stays a step of the person's run",
       expect="said just after the refusal", script=S)

# The chat line deferred for the late error said anyway once it was taken back.
mutate("Queue.lua",
       "\t\t\t\t\tif r.said then ns.Guard(\"refusal line\", Tell, name, r.why) end\n",
       "\t\t\t\t\tns.Guard(\"refusal line\", Tell, name, r.why)\n",
       "par-core1: the chat line said over a step taken back",
       expect="par-core1: a late out of sight on the third refusal takes the step back", script=S)

# The spoken line let go with the back-off, over the press that is refused again.
mutate("Queue.lua",
       "\t\tif hold and quiet > r.quietUntil then r.quietUntil = quiet end\n",
       "",
       "par-core1: where they stand lets the line go with the back-off",
       expect="par-core1: refused SPELL_FAILED_LINE_OF_SIGHT three times", script=S)

# The player's own target backed off for where they stand, with nothing to lift it.
mutate("Queue.lua",
       "\t\tif name == pointedAt and ns.UnitFullName(\"target\") == pointedAt then return end\n",
       "",
       "par-core1: your own target backed off for where they stand",
       expect="par-core1: your own target out of sight is not backed off", script=S)

# ------------------------------------------------ 3. the row under the cursor

# The list painted in the queue's order under the cursor.
mutate("Prompt/List.lua",
       "\trows = self:HoldRows(rows)\n",
       "",
       "par-core1: the list reshuffles under the cursor",
       expect="par-core1: the name under the cursor stays put", script=S)

# A line whose person left handed the next name.
mutate("Prompt/Rows.lua",
       "\t\t\tif not out[i] then out[i] = Blank(name) end\n",
       "",
       "par-core1: a line whose person left takes the next name",
       expect="par-core1: the line under the cursor goes blank", script=S)

# The blank line hidden, so the cursor falls off it and the next name comes up.
mutate("Prompt/Rows.lua",
       "\t\telseif data and data.held and row.hovered then\n",
       "\t\telseif false then\n",
       "par-core1: the blank line under the cursor is hidden",
       expect="par-core1: the line under the cursor goes blank", script=S)

# The hold outliving the cursor.
mutate("Prompt/Rows.lua",
       "\t\tif not row.hovered then\n\t\t\trow.held = nil\n",
       "\t\tif not row.hovered then\n",
       "par-core1: the line stays held once the cursor leaves",
       expect="with the cursor gone", script=S)
