# Mutations for the review of cures (Cures.lua and its hooks): nothing is
# offered that would lift a debuff never removed, a passer-by read with
# nothing to cure is let go by the memory and by the prompt's hold, and a
# press on a cure leaves the buff rotation alone. Each is caught by the
# scenario in tests/scenarios/cures-review.lua that names it.

S = "runscenarios.py"

DENY = "cures-review: nothing that would lift a debuff never removed is offered beside it"
CLEAN = "cures-review: a passer-by read clean is not offered the cure from memory"
READ = "cures-review: a reading with nothing to cure ends the memory of a passer-by"
ROTA = "cures-review: a cure pressed leaves the buff rotation where it stood"

# The deny list hides only the denied debuff: Cleanse offered for a poison
# beside Unstable Affliction.
mutate("Modules/Combat/Cures.lua",
       "\tif not anyDenied then return end\n",
       "\tif true then return end\n",
       "cures-review: a denied debuff hides only itself",
       expect=DENY, script=S)

# No spell that spares the denied kind is looked for: a poison beside it is
# offered nothing with Purify known.
mutate("Modules/Combat/Cures.lua",
       "\t\t\tif other then list[i].cure = other else table.remove(list, i) end\n",
       "\t\t\ttable.remove(list, i)\n",
       "cures-review: no second spell for a debuff beside a denied one",
       expect=DENY, script=S)

# A kind's second spell is taken for one a probe took away.
mutate("Modules/Combat/Cures.lua",
       "\t\tif not scan.state.live[cure] then\n",
       "\t\tif scan.byKind[cure.cure] ~= cure then\n",
       "cures-review: a kind's second spell is never offered",
       expect=DENY, script=S)

# No verdict for a passer-by read with nothing to cure: the memory offers the
# cure again, and the prompt's hold keeps them.
mutate("Queue.lua",
       "\t\t\tif reason == \"nearby\" and (not db.sources.strangers or groupOnly) then\n"
       "\t\t\t\trejected[full] = true\n",
       "\t\t\tif reason == \"nearby\" and (not db.sources.strangers or groupOnly) then\n",
       "cures-review: no verdict for a passer-by with nothing to cure",
       expect=CLEAN, script=S)

# The reading that finds nothing leaves the memory standing.
mutate("Modules/Combat/Cures.lua",
       "\tForget(full)\n\treturn nil\n",
       "\treturn nil\n",
       "cures-review: a clean reading leaves the memory standing",
       expect=READ, script=S)

# The press writes the cure's key over the rotation pointer.
mutate("Prompt/Press.lua",
       "\t\tif ns.RotatesBuffs() and not S.current.cure then\n",
       "\t\tif ns.RotatesBuffs() then\n",
       "cures-review: a cure pressed moves the rotation",
       expect=ROTA, script=S)

# And the settle writes it again.
mutate("Clicks.lua",
       "\tif pending.buffKey and not pending.cure and ns.RotatesBuffs() then\n",
       "\tif pending.buffKey and ns.RotatesBuffs() then\n",
       "cures-review: a cure settled moves the rotation",
       expect=ROTA, script=S)
