# Mutations for the companion pet (Buffs.lua PET, Pets.lua, Companion.lua, Core.lua's
# default, ReadOwnFamily, OwnVerdict and KnownOwnFamilies, Commands.lua, Options/Who.lua,
# Options/Shared.lua): a family on Forever, Classic Era and Burning Crusade, off by
# default, a bag pet on the prompt by Manners' own count, Forever's journal brought
# out with no press, the holds, the player's putting away, the refusals. Each is
# caught by the scenario in tests/scenarios/pets.lua that names it.

S = "runscenarios.py"

# --- the family ---

mutate("Buffs.lua",
       "\tfor _, family in ipairs({ FOOD[client] or false, REST[client] or false, PET[client] or false }) do\n",
       "\tfor _, family in ipairs({ FOOD[client] or false, REST[client] or false }) do\n",
       "pets: the family in no class's list",
       expect="pets: Forever, Classic Era and TBC give every class the family", script=S)

mutate("Buffs.lua",
       "\t\t\tjournal = client == \"camelot\" or nil, spells = spells }\n",
       "\t\t\tjournal = nil, spells = spells }\n",
       "pets: Forever without its journal",
       expect="pets: Forever, Classic Era and TBC give every class the family", script=S)

mutate("Core.lua",
       "\t\tif family.pet then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "",
       "pets: on by default",
       expect="pets: off by default", script=S)

# --- whether one is out ---

mutate("Core.lua",
       "\t\tif family.pet then return ns.ReadPet(family) end\n",
       "",
       "pets: read as an aura",
       expect="pets: its use puts it out", script=S)

mutate("Companion.lua",
       "\tif mine.out == spell.key then\n\t\tmine.out, mine.dismissed = nil, true\n",
       "\tif false then\n\t\tmine.out, mine.dismissed = nil, true\n",
       "pets: the same use again read as putting it out",
       expect="pets: its use puts it out, the same use again puts it away", script=S)

mutate("Companion.lua",
       "\t\tif unit == \"player\" then self:Cast(spellId) end\n",
       "\t\tself:Cast(spellId)\n",
       "pets: anybody's cast counted as yours",
       expect="pets: its use puts it out, the same use again puts it away", script=S)

mutate("Companion.lua",
       "\telseif event == \"PLAYER_DEAD\" then\n\t\tself:Gone(false)\n",
       "\telseif event == \"PLAYER_DEAD\" then\n",
       "pets: death leaves the pet counted out",
       expect="pets: death and a loading screen take the pet", script=S)

mutate("Companion.lua",
       "\t\tif reload == true then\n",
       "\t\tif false then\n",
       "pets: a reload takes the pet",
       expect="pets: death and a loading screen take the pet, a reload does not", script=S)

mutate("Companion.lua",
       "\tif settle then session.quietUntil = GetTime() + SETTLE end\n",
       "",
       "pets: no settling after a loading screen",
       expect="pets: death and a loading screen take the pet", script=S)

# --- the holds ---

mutate("Companion.lua",
       "\tif Yes(_G.IsMounted) then return \"mounted\" end\n",
       "",
       "pets: offered mounted",
       expect="pets: not mounted, in an instance or stealthed", script=S)

mutate("Companion.lua",
       "\tif Instanced() then return \"instance\" end\n",
       "",
       "pets: offered in an instance",
       expect="pets: not mounted, in an instance or stealthed", script=S)

mutate("Companion.lua",
       "\t\tor Yes(_G.IsStealthed) then\n",
       "\t\tthen\n",
       "pets: offered stealthed",
       expect="pets: not mounted, in an instance or stealthed", script=S)

mutate("Core.lua",
       "\t\t\tif hold then return nil, up, nil, hold, spell end\n",
       "",
       "pets: the holds ignored",
       expect="pets: not mounted, in an instance or stealthed", script=S)

mutate("Companion.lua",
       "\tif mine and mine.dismissed then return \"dismissed\" end\n",
       "",
       "pets: a pet put away brought back",
       expect="pets: a pet the player puts away from the journal stays away", script=S)

# --- the journal ---

mutate("Core.lua",
       "\t\t\tif journal then return nil, up, nil, \"journal\" end\n",
       "",
       "pets: the journal never asked",
       expect="pets: Forever brings a pet out of the journal itself", script=S)

mutate("Companion.lua",
       "\tif choice == \"last\" and mine and Summonable(mine.guid) then return mine.guid end\n",
       "",
       "pets: the pet out last forgotten",
       expect="pets: Forever brings a pet out of the journal itself", script=S)

mutate("Companion.lua",
       "\tif choice == \"random\" then return \"random\" end\n",
       "",
       "pets: any pet read as a favourite",
       expect="pets: Which pet brings out a favourite, or any pet", script=S)

mutate("Companion.lua",
       "\tif InCombatLockdown() then return end\n",
       "",
       "pets: summoned in a fight",
       expect="pets: the journal is not touched with the switch off, in a fight", script=S)

mutate("Companion.lua",
       "\treturn family ~= nil and family.journal == true and ns.OwnPick(family) ~= \"off\"\n",
       "\treturn family ~= nil and family.journal == true\n",
       "pets: the journal asked with the switch off",
       expect="pets: the journal is not touched with the switch off", script=S)

mutate("Companion.lua",
       "\tif mine and JournalOut() == false and (asked.guid == nil or asked.guid == mine.guid) then\n",
       "\tif mine then\n",
       "pets: another pet chosen read as put away",
       expect="pets: a summon of another pet is no putting away", script=S)

mutate("Companion.lua",
       "\tsession.asked = { guid = plain(guid), at = GetTime() }\n",
       "",
       "pets: the player's putting away unheard",
       expect="pets: a pet the player puts away from the journal stays away", script=S)

mutate("Companion.lua",
       "\t\t\tif session.failures >= GIVE_UP and not session.refused then\n",
       "\t\t\tif false then\n",
       "pets: a refusing journal asked for ever",
       expect="pets: a journal that brings nothing out three times", script=S)

mutate("Companion.lua",
       "\t\tif who == \"Manners\" and type(what) == \"string\" and what:find(\"Pet\", 1, true) then\n",
       "\t\tif type(what) == \"string\" and what:find(\"Pet\", 1, true) then\n",
       "pets: another addon's refusal taken for Manners'",
       expect="pets: the game naming Manners for a pet call stops the journal", script=S)

mutate("Companion.lua",
       "\t\tif type(n) == \"number\" and n > 0 then return false end\n",
       "",
       "pets: the journal over a bag pet used last",
       expect="pets: on Forever a bag pet used last is offered before the journal", script=S)

mutate("Companion.lua",
       "\t\tif JournalOut() then\n\t\t\tsession.failures = 0\n",
       "\t\tif false then\n\t\t\tsession.failures = 0\n",
       "pets: a summon that worked counted as refused",
       expect="pets: summons that work never add up to a refusal", script=S)

# --- what the page and the debug lines say ---

mutate("Options/Who.lua",
       "\t\t\t\t\tif family.pet then return pick() == \"off\" and not Page.BaggedHeld(family) end\n",
       "\t\t\t\t\tif family.pet then return true end\n",
       "pets: the switch never shown",
       expect="pets: off by default, the bags unread, and a switch shown", script=S)

mutate("Options/Shared.lua",
       "\tif family.journal and ns.PetJournalOwned() then return true end\n",
       "",
       "pets: the journal's pets not counted for the switch",
       expect="pets: Forever shows the switch for a pet in the journal", script=S)

mutate("Core.lua",
       "\toneOf(profile.ownBuffs, \"petChoice\", { last = true, favourite = true, random = true }, \"last\")\n",
       "",
       "pets: a nonsense Which pet kept",
       expect="pets: Forever shows the switch for a pet in the journal, and Which pet", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"up\" and family.pet then\n",
       "\t\telseif false then\n",
       "pets: a pet out said as the label up",
       expect="pets: its use puts it out", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"dismissed\" then\n",
       "\t\telseif false then\n",
       "pets: putting away unsaid",
       expect="pets: its use puts it out, the same use again puts it away", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"instance\" then\n",
       "\t\telseif false then\n",
       "pets: the instance unsaid",
       expect="pets: not mounted, in an instance or stealthed", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"refused\" then\n",
       "\t\telseif false then\n",
       "pets: the refusal unsaid",
       expect="pets: a journal that brings nothing out three times", script=S)
