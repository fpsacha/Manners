# Mutations for the companion pet on Mists and retail (Buffs.lua's family with no
# bag rows, Companion.lua's `journalOnly`: what is registered, the two holds of its
# own, which COMPANION_UPDATE is read, the player's putting away; Commands.lua's
# line; Options/Who.lua's description and Which pet for a class with nothing for
# others). Each is caught by the scenario in tests/scenarios/journalpet.lua that
# names it.

S = "runscenarios.py"

# --- the family ---

mutate("Buffs.lua",
       "for _, client in ipairs({ \"mists\", \"mainline\" }) do\n\tPET[client] = PET[client] or {",
       "for _, client in ipairs({}) do\n\tPET[client] = PET[client] or {",
       "journalpet: no family on Mists and retail",
       expect="journalpet: Mists and retail give every class the journal's family", script=S)

mutate("Buffs.lua",
       "\t\ttoggle = true, journal = true, spells = {} }\n",
       "\t\ttoggle = true, journal = nil, spells = {} }\n",
       "journalpet: the family without its journal",
       expect="journalpet: Mists and retail give every class the journal's family", script=S)

# --- what Companion.lua registers there ---

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tjournalOnly, Pet.journalOnly = true, true\n",
       "\t\tPet.journalOnly = true\n",
       "journalpet: the journal-only rules never switched on",
       expect="journalpet: not in a pet battle", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\t\t\t\"ADDON_ACTION_FORBIDDEN\", \"ADDON_ACTION_BLOCKED\", \"COMPANION_UPDATE\", \"PET_BATTLE_CLOSE\" }) do\n",
       "\t\t\t\"ADDON_ACTION_FORBIDDEN\", \"ADDON_ACTION_BLOCKED\", \"PET_BATTLE_CLOSE\" }) do\n",
       "journalpet: the pet changing unheard",
       expect="journalpet: a pet comes out of the journal with no press", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\t\t\t\"ADDON_ACTION_FORBIDDEN\", \"ADDON_ACTION_BLOCKED\", \"COMPANION_UPDATE\", \"PET_BATTLE_CLOSE\" }) do\n",
       "\t\t\t\"ADDON_ACTION_BLOCKED\", \"COMPANION_UPDATE\", \"PET_BATTLE_CLOSE\" }) do\n",
       "journalpet: the game's refusal unheard",
       expect="journalpet: the game naming Manners for a pet call stops the journal", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tfor _, event in ipairs({ \"PLAYER_ENTERING_WORLD\", \"PLAYER_ALIVE\",",
       "\t\tfor _, event in ipairs({ \"UNIT_SPELLCAST_SUCCEEDED\", \"PLAYER_ENTERING_WORLD\", \"PLAYER_ALIVE\",",
       "journalpet: every cast listened to for a bag pet that does not exist",
       expect="journalpet: just loaded in the game is given a moment, and no cast is listened to", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\n\t\t\tif type(journal.SummonPetByGUID) == \"function\" then\n"
       "\t\t\t\thooksecurefunc(journal, \"SummonPetByGUID\", function(guid) Pet:PutAway(guid) end)\n",
       "\n\t\t\tif false then\n"
       "\t\t\t\thooksecurefunc(journal, \"SummonPetByGUID\", function(guid) Pet:PutAway(guid) end)\n",
       "journalpet: the journal's toggle not watched",
       expect="journalpet: a pet the player puts away from the journal stays away", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\n\t\t\tif type(journal.DismissSummonedPet) == \"function\" then\n"
       "\t\t\t\thooksecurefunc(journal, \"DismissSummonedPet\", function() Pet:PutAway(nil) end)\n",
       "\n\t\t\tif false then\n"
       "\t\t\t\thooksecurefunc(journal, \"DismissSummonedPet\", function() Pet:PutAway(nil) end)\n",
       "journalpet: the journal's Dismiss not watched",
       expect="journalpet: a pet the player puts away from the journal stays away", script=S)

# --- the holds of its own ---

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tif InPetBattle() then return \"petbattle\" end\n",
       "",
       "journalpet: summoned in a pet battle",
       expect="journalpet: not in a pet battle", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tif Yes(_G.IsFlying) then return \"petbusy\" end\n",
       "",
       "journalpet: summoned in the air",
       expect="journalpet: held in a fight, an instance, mounted, stealthed, in the air", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\tif journalOnly then\n\t\tif InPetBattle() then",
       "\tif true then\n\t\tif InPetBattle() then",
       "journalpet: Forever held by Mists' and retail's holds",
       expect="journalpet: Forever still reads an update with no kind, and is not held", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\telseif event == \"PET_BATTLE_CLOSE\" then\n"
       "\t\t-- The game brings your pet back itself after a pet battle: a moment for\n"
       "\t\t-- it, as after a loading screen.\n"
       "\t\tsession.quietUntil = GetTime() + SETTLE\n",
       "\telseif event == \"PET_BATTLE_CLOSE\" then\n",
       "journalpet: no moment after a pet battle",
       expect="journalpet: not in a pet battle, and a moment after it", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"petbattle\" then\n",
       "\t\telseif why == \"never\" then\n",
       "journalpet: the pet battle unsaid",
       expect="journalpet: not in a pet battle", script=S)

# --- which update is read ---

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tif kind ~= \"MOUNT\" and (kind == \"CRITTER\" or not journalOnly) then self:JournalChanged() end\n",
       "\t\tif kind ~= \"MOUNT\" then self:JournalChanged() end\n",
       "journalpet: every passer-by's pet read",
       expect="journalpet: only your own pet's update is read on Mists and retail", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "\t\tif kind ~= \"MOUNT\" and (kind == \"CRITTER\" or not journalOnly) then self:JournalChanged() end\n",
       "\t\tif kind == \"CRITTER\" then self:JournalChanged() end\n",
       "journalpet: Forever's update with no kind dropped",
       expect="journalpet: Forever still reads an update with no kind", script=S)

# --- the player's putting away ---

mutate("Modules/MyBuffs/Companion.lua",
       "\tif journalOnly and not self:Wanted() then return end\n",
       "",
       "journalpet: a pet put away with the switch off kept against the player",
       expect="journalpet: a pet put away before the switch was on", script=S)

# --- the options page ---

mutate("Modules/MyBuffs/Options.lua",
       "\t\t\t\t\tor family.pet and family.journal and #family.spells == 0\n",
       "\t\t\t\t\tor false\n",
       "journalpet: the switch described with Forever's bag pets",
       expect="journalpet: off by default, and the switch is shown for a pet in the journal", script=S)

mutate("Options/Who.lua",
       " or key == \"ownPetChoice\"\n",
       "\n",
       "journalpet: Which pet hidden from a class with nothing for others",
       expect="journalpet: off by default, and the switch is shown for a pet in the journal", script=S)
