# Mutations for GitHub issue 18 (Buffs.lua's Demonic Pact split and the stone to
# make, Core.lua's probe, reading and reagent, the layout slots). Each is caught
# by the scenario in tests/scenarios/issue18.lua that names it.

S = "runscenarios.py"

# The probe ignores what Demonic Pact asks: Soul Link never has a family of its own.
mutate("Core.lua",
       "\t\t\t\tif info.known and ((spell.needsSpell and not SpellKnown(spell.needsSpell))\n",
       "\t\t\t\tif false and ((spell.needsSpell and not SpellKnown(spell.needsSpell))\n",
       "issue18: the probe never reads Demonic Pact",
       expect="issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of", script=S)

# The new family known whether or not the Pact is: two families for every warlock.
mutate("Core.lua",
       "\t\t\t\tif info.known and ((spell.needsSpell and not SpellKnown(spell.needsSpell))\n",
       "\t\t\t\tif info.known and ((spell.needsSpell and false)\n",
       "issue18: Soul Link of its own without Demonic Pact",
       expect="issue18: forever: without Demonic Pact, Soul Link and Demonic Sacrifice stay one choice", script=S)

# The old family keeps Soul Link with the Pact: its aura hides the sacrifice.
mutate("Buffs.lua",
       "\t\t\t\tif each.key == \"soullink\" then each.notWithSpell = DEMONIC_PACT end\n",
       "",
       "issue18: Soul Link stays in the sacrifice's family with the Pact",
       expect="issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of", script=S)

# Soul Link ahead of the sacrifice, which would take its demon.
mutate("Buffs.lua",
       "\t\t\ttable.insert(list, i + 1, { key = \"soullink\", toggle = true, pact = true,\n",
       "\t\t\ttable.insert(list, i, { key = \"soullink\", toggle = true, pact = true,\n",
       "issue18: Soul Link offered before the sacrifice",
       expect="issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of", script=S)

# The new Soul Link read as anybody's aura but the pet's: never up.
mutate("Buffs.lua",
       "\t\t\t\tspells = { { key = \"soullinkpact\", ranks = { 19028, 25228 }, talent = true, byPet = true,\n",
       "\t\t\t\tspells = { { key = \"soullinkpact\", ranks = { 19028, 25228 }, talent = true,\n",
       "issue18: the Pact's Soul Link not read from the demon",
       expect="issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of", script=S)

# Learning the talent noticed only at a reload: the probe stops answering changes.
mutate("Core.lua",
       "\t\t\t\tif info.known and ((spell.needsSpell and not SpellKnown(spell.needsSpell))\n",
       "\t\t\t\tif ns.pactAtLoad == nil then ns.pactAtLoad = SpellKnown(425464) end\n"
       "\t\t\t\tif info.known and ((spell.needsSpell and not ns.pactAtLoad)\n",
       "issue18: Demonic Pact read once at login",
       expect="issue18: forever: Demonic Pact learned mid-session takes effect without a reload", script=S)

# The split made on every client: Classic Era and TBC changed.
mutate("Buffs.lua",
       "\tlocal list = CAMELOT_OWN.WARLOCK\n\tfor i, family in ipairs(list) do\n\t\tif family.key == \"demonicsacrifice\" then\n",
       "\tlocal list = CAMELOT_OWN.WARLOCK\n\tfor _, l in ipairs({ VANILLA_OWN.WARLOCK, TBC_OWN.WARLOCK }) do\n"
       "\t\tfor _, f in ipairs(l) do if f.key == \"demonicsacrifice\" then for _, s in ipairs(f.spells) do\n"
       "\t\t\tif s.key == \"soullink\" then s.notWithSpell = DEMONIC_PACT end end end end\n\tend\n"
       "\tfor i, family in ipairs(list) do\n\t\tif family.key == \"demonicsacrifice\" then\n",
       "issue18: the Pact read on Classic Era and TBC",
       expect="issue18: vanilla: the warlock's family is as it was", script=S)

# The page's Soul Link switch not placed.
mutate("Modules/MyBuffs/Layout.lua",
       "\t\t\t\t\t{ \"who.own_soullink\", indent = true },\n",
       "",
       "issue18: Soul Link's switch not placed on the page",
       expect="issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of", script=S)

# --- the stone to make ---

# On by default.
mutate("Buffs.lua",
       "label = L[\"Make a Firestone or Spellstone\"], optIn = true,",
       "label = L[\"Make a Firestone or Spellstone\"],",
       "issue18: making a stone on by default",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# Never read as up: offered with a stone in the bags or on the weapon.
mutate("Core.lua",
       "\t\tif family.makes then return ReadMakes(family) end\n",
       "\t\tif family.makes then return false end\n",
       "issue18: a stone to make offered with one to hand",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# The stone on the weapon not counted.
mutate("Core.lua",
       "\t\tlocal on, stone = ReadImbue(stones)\n\t\tif not on then return on end\n",
       "\t\tlocal on, stone = false, nil\n\t\tif not on then return on end\n",
       "issue18: a stone on the weapon not seen",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# Automatic never takes the kind last on the weapon.
mutate("Core.lua",
       "\t\t\t\tif item == stone.item then\n\t\t\t\t\tRemember(family, spell)\n",
       "\t\t\t\tif item == stone.item then\n",
       "issue18: the kind of stone used last forgotten",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# No Soul Shard asked for.
mutate("Core.lua",
       "\t\telseif family.reagent and ns.OwnReagentCount(family) <= 0 then\n",
       "\t\telseif false then\n",
       "issue18: a stone to make offered without a Soul Shard",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# The shard never counted: never offered.
mutate("Core.lua",
       "\t\t\t\t\t\tscrollCounts[reagent] = type(n) == \"number\" and n or 0\n",
       "\t\t\t\t\t\tscrollCounts[reagent] = 0\n",
       "issue18: the Soul Shard never counted",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# Offered with no weapon in the main hand.
mutate("Buffs.lua",
       "\t\t\t\t\t{ key = \"createfirestone\", ranks = { 17953, 17952, 17951, 6366 }, needsWeapon = true,\n",
       "\t\t\t\t\t{ key = \"createfirestone\", ranks = { 17953, 17952, 17951, 6366 },\n",
       "issue18: a Firestone to make with no weapon",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# /manners debug quiet about the shard.
mutate("Commands.lua",
       "\t\telseif why == \"reagent\" then\n",
       "\t\telseif why == \"reagent!\" then\n",
       "issue18: /manners debug quiet about the Soul Shard",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)

# The switch not placed.
mutate("Modules/MyBuffs/Layout.lua",
       "\t\t\t\t\t{ \"who.own_makestone\", indent = true },\n",
       "",
       "issue18: the stone's switch not placed on the page",
       expect="issue18: forever: a stone is offered to be made only when the spell is known", script=S)
