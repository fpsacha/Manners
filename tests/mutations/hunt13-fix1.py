# Mutations for the fixes from round 13's first fixer: a buff you cannot pay
# for (Queue.lua, Affordable), a party member out of sight however they came
# onto the prompt (Queue.lua), and {class} in the client's words (Core.lua,
# ns.ClassName; Prompt.lua). Each undoes a fix and is caught by the scenario
# in tests/scenarios/hunt13-fix1.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ a buff you cannot pay for
# The report: only exactly 0 mana stopped the queue, so an Intellect costing
# more than the mana left was offered, and failed, on every press.
mutate("Queue.lua",
       "\tlocal candidates = Affordable(ns.CastableBuffs())\n",
       "\tlocal candidates = ns.CastableBuffs()\n",
       "fix1: the scan offers what you cannot pay for",
       expect="hunt13-fix1: a buff you cannot pay for is offered to nobody (C_Spell)", script=S)

# Any no taken for want of mana: a druid in cat form, a priest in Shadowform,
# lose every buff the macro could still get them out of the form to cast.
mutate("Queue.lua",
       "\t\tif not (usable == false and noMana == true) then\n",
       "\t\tif usable ~= false then\n",
       "fix1: a plain no taken for want of mana",
       expect="hunt13-fix1: a no that is not for want of mana keeps the buff on offer (a form)", script=S)

# A client that will not say taken for a no.
mutate("Queue.lua",
       "\t\tif not (usable == false and noMana == true) then\n",
       "\t\tif usable == true then\n",
       "fix1: silence taken for a no",
       expect="hunt13-fix1: a no that is not for want of mana keeps the buff on offer (the client will not say)",
       script=S)

# Every spell judged alone, the pin too: PickBuffFor swaps whatever is left
# for the pin, which is offered after all.
mutate("Queue.lua",
       "\t\telseif pinned and pinned.key == buff.key then\n",
       "\t\telseif false then\n",
       "fix1: a pin you cannot pay for is offered in another's place",
       expect="hunt13-fix1: a pinned buff you cannot pay for is offered to nobody", script=S)

# The other way round: one spell you cannot pay for takes every other with it.
mutate("Queue.lua",
       "\t\telseif pinned and pinned.key == buff.key then\n",
       "\t\telse\n",
       "fix1: one spell you cannot pay for empties the list",
       expect="hunt13-fix1: a spell you can pay for is still offered beside one you cannot", script=S)

# Only the modern call asked: the older clients' IsUsableSpell never is.
mutate("Queue.lua",
       "\tif type(check) ~= \"function\" then check = _G.IsUsableSpell end\n"
       "\tif type(check) ~= \"function\" then return candidates end\n",
       "\tif type(check) ~= \"function\" then return candidates end\n",
       "fix1: the older IsUsableSpell is not asked",
       expect="hunt13-fix1: a buff you cannot pay for is offered to nobody (the older call)", script=S)

# ------------------------------------------------ out of sight, whatever the reason
# The report: the test keyed on the reason, so a favour or a request skipped it.
mutate("Queue.lua",
       "\t\tif inGroup and f.requireInRange\n",
       "\t\tif reason == \"group\" and f.requireInRange\n",
       "fix1: out of sight asked of the group reason only",
       expect="hunt13-fix1: a party member out of sight is not offered though owed", script=S)

mutate("Queue.lua",
       "\t\tif inGroup and f.requireInRange\n",
       "\t\tif (reason == \"group\" or reason == \"owed\") and f.requireInRange\n",
       "fix1: out of sight not asked of somebody asking",
       expect="hunt13-fix1: a party member out of sight is not offered though asking", script=S)

# ------------------------------------------------ {class} in the client's words
mutate("Prompt/Paint.lua",
       "\tout = Swap(out, \"{class}\", ns.ClassName(entry.class))\n",
       "\tout = Swap(out, \"{class}\", entry.class)\n",
       "fix1: {class} prints the token",
       expect="with the client's class names the panel reads", script=S)

# The client's own names never read: English on every client.
mutate("Core.lua",
       "\tlocal name = type(names) == \"table\" and plain(names[class]) or nil\n"
       "\tif type(name) == \"string\" then return name end\n"
       "\treturn class:sub(1, 1) .. class:sub(2):lower()\n",
       "\treturn class:sub(1, 1) .. class:sub(2):lower()\n",
       "fix1: class names always English",
       expect="with the client's class names the panel reads", script=S)

# Nothing to fall back on where the client has no table.
mutate("Core.lua",
       "\tif type(name) == \"string\" then return name end\n"
       "\treturn class:sub(1, 1) .. class:sub(2):lower()\n",
       "\tif type(name) == \"string\" then return name end\n"
       "\treturn class\n",
       "fix1: no class names falls back to the token",
       expect="with no class names the first line reads", script=S)

# No class at all throws, where it used to read as nothing.
mutate("Core.lua",
       "\tif type(class) ~= \"string\" or class == \"\" then return nil end\n"
       "\tlocal names = _G.LOCALIZED_CLASS_NAMES_MALE\n",
       "\tlocal names = _G.LOCALIZED_CLASS_NAMES_MALE\n",
       "fix1: no class throws",
       expect="with no class at all the first line reads", script=S)
