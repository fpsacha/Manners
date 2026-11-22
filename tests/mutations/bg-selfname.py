# Mutations for the name a cast on yourself carries (GitHub issue 38): after a
# death in a battleground, Clicks.lua's NamesYou decides whether a cast was on
# you (the filed name, with the surname on Forever, or the first name alone),
# and Queue.lua's NoteRefusal reads "a stronger one is on you" as the buff
# being there. Each is caught by the scenario in tests/scenarios/bg-selfname.lua
# that it names.

S = "runscenarios.py"

# --- the cast event's target ---
# (Dropping only the last clause of NamesYou, the realm-suffixed spelling,
# changes nothing on Forever, where a name carries no realm: no scenario here
# can catch it.)

mutate("Clicks.lua",
       " or ns.IsPlayerName(to)",
       "",
       "bg-selfname: your name with the surname is not yours",
       expect="bg-selfname: a cast on yourself named with your surname lets the hidden reading stand", script=S)

mutate("Clicks.lua",
       "\treturn to == first or ns.IsPlayerName(to) or (first ~= nil and ns.ShortName(to) == first)\n",
       "\treturn ns.IsPlayerName(to)\n",
       "bg-selfname: your first name alone is not yours",
       expect="bg-selfname: a cast on yourself named by first name alone still counts", script=S)

mutate("Clicks.lua",
       "\treturn to == first or ns.IsPlayerName(to) or (first ~= nil and ns.ShortName(to) == first)\n",
       "\treturn true\n",
       "bg-selfname: anybody's name is yours",
       expect="bg-selfname: a cast on somebody sharing your first name leaves your reading as it was", script=S)

# --- the game's answer ---

mutate("Queue.lua",
       "\t\t\tif not members and ns.IsPlayerName(name) and OneOf(why, BOUNCED) then ns.NoteCastSinceDeath(buffKey) end\n",
       "",
       "bg-selfname: a stronger one on you is not noted",
       expect="bg-selfname: the game saying a stronger one is on you ends the guess", script=S)

mutate("Queue.lua",
       "not members and ns.IsPlayerName(name) and OneOf(why, BOUNCED)",
       "not members and OneOf(why, BOUNCED)",
       "bg-selfname: a stronger one on a team-mate is noted as yours",
       expect="bg-selfname: a stronger one on a team-mate leaves your own reading as it was", script=S)
