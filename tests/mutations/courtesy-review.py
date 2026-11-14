# Mutations for the review of a class's courtesies on request (Courtesy.lua
# and its hook in Queue.lua's BuildQueue): one portal for a city with two,
# one refreshment for water and food where they are one, a conjure that
# failed asked for again, a trade the asker opened themselves, and the walk
# for a cure and the ask kept while a courtesy stands. Each undoes one fix and
# is caught by the scenario in tests/scenarios/courtesy-review.lua that names
# it.

S = "runscenarios.py"

CITY = "courtesy-review: a city with two portals learned is answered with one portal"
ORDER = "courtesy-review: two portals asked for are answered in the client's order"
BOTH = "courtesy-review: mists: water and food asked for together are one refreshment"
FAILED = "courtesy-review: a conjure that failed is offered again, not a trade of water they cannot drink"
THEIRS = "courtesy-review: a trade the asker opens themselves gets the water and answers the request"
OPEN = "courtesy-review: a press with her trade already open puts the water in it"
CURE = "courtesy-review: a courtesy standing does not stop the walk for a cure"
ASK = "courtesy-review: a courtesy standing does not stop the ask"

# Two portals to one city are two things asked for: "portal to dal pls" is
# answered twice.
mutate("Courtesy.lua",
       "\t\t\t\t\t\t\t\task.twin = earlier.key\n",
       "",
       "courtesy-review: a city with two portals is two requests",
       expect=CITY, script=S)

# Of the two, the later in the list always takes the request.
mutate("Courtesy.lua",
       "\t\t\t\tif not (twin and found[twin] and count <= (cityWords[twin] or 0)) then\n",
       "\t\t\t\tif true then\n",
       "courtesy-review: the second portal of a city is the one offered",
       expect=CITY, script=S)

# Portals answered by spell id again, not by their place in the client's list.
mutate("Courtesy.lua",
       "\t\t\treturn (place[name] or 99) * 1e8 + (spot[tonumber(id) or 0] or 0)\n",
       "\t\t\treturn (place[name] or 99) * 1e8 + (tonumber(id) or 0)\n",
       "courtesy-review: portals answered in the order of their ids",
       expect=ORDER, script=S)

# A key blocked by its own press lets the next one through: food is offered
# while the water's conjure is on its way.
mutate("Courtesy.lua",
       "\t\t\t\t\t\t\twhy = why or \"pressed\"\n\t\t\t\t\t\t\tbreak\n",
       "\t\t\t\t\t\t\twhy = why or \"pressed\"\n",
       "courtesy-review: the next thing asked for is offered over a press",
       expect=BOTH, script=S)

# The one trade answers water alone: food still stands, and is conjured and
# traded a second time.
mutate("Courtesy.lua",
       "\tif other and request.keys[other] and Both(MySet()) then request.keys[other] = nil end\n",
       "",
       "courtesy-review: one refreshment answers only half the request",
       expect=BOTH, script=S)

# Conjured for them at the press, whatever became of the cast.
mutate("Courtesy.lua",
       "\t\twaiting.conjure = { request = request, spell = plan.spell, at = now }\n",
       "\t\tState(request).conjured = true\n",
       "courtesy-review: a conjure counts as made at the press",
       expect=FAILED, script=S)

# Any cast of yours counts as the conjure going out.
mutate("Courtesy.lua",
       "\t\telseif plain(spellId) == made.spell then\n",
       "\t\telse\n",
       "courtesy-review: any cast counts as the conjure",
       expect=FAILED, script=S)

# A trade no press asked for is left alone: nothing goes into the one they
# opened themselves.
mutate("Courtesy.lua",
       "\tif not (set and list) then return end\n\tlocal now = GetTime()\n\tfor i = #list, 1, -1 do\n",
       "\tif true then return end\n\tlocal now = GetTime()\n\tfor i = #list, 1, -1 do\n",
       "courtesy-review: a trade the asker opened gets nothing",
       expect=THEIRS, script=S)

# What they asked for goes into a trade anybody opens.
mutate("Courtesy.lua",
       "\t\t\tand (request.fight or request.expires > now) and Matches(request, \"NPC\") then\n",
       "\t\t\tand (request.fight or request.expires > now) then\n",
       "courtesy-review: the water goes into a trade somebody else opened",
       expect=THEIRS, script=S)

# The press never looks for a trade already open with them: it waits for a
# window that will not open again.
mutate("Courtesy.lua",
       "\t\tif type(request) == \"table\" and not InCombatLockdown() and TradingWith(request) then\n",
       "\t\tif false then\n",
       "courtesy-review: a press with the trade already open places nothing",
       expect=OPEN, script=S)

# A courtesy standing takes the early way out even with a cure to walk for.
mutate("Queue.lua",
       "battle ~= \"fight\" and not ns.CureScanned() and ns.Courtesy and ns.Courtesy.Standing(now) then\n",
       "battle ~= \"fight\" and ns.Courtesy and ns.Courtesy.Standing(now) then\n",
       "courtesy-review: no walk for a cure while a courtesy stands",
       expect=CURE, script=S)

# And its queue is handed back without somebody to ask.
mutate("Queue.lua",
       "\t\tif db.sources.ask == true and ns.AskInto then return ns.AskInto(ns.Courtesy.Alone(SelfEntry(db, candidates, now, neverVerdict), now, inTown, manaHoldsAsked)) end\n",
       "",
       "courtesy-review: nobody asked while a courtesy stands",
       expect=ASK, script=S)
