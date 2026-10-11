# Mutations for the logic bug hunt's fixes: the capability probe taken again
# when a restriction ends (Core.lua), and a request for a spell offered on
# request only served when nothing else is castable (Queue.lua, Requests.lua).
# Each undoes a fix and is caught by the scenario in
# tests/scenarios/hunt-logic-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------- a probe taken in a restriction
# The report: a probe taken inside a restriction (a /reload mid-fight, a key
# under way) noted every buff as hidden, and nothing took it again until the
# next loading screen or spellbook change.

# The fight ending taking the probe again.
mutate("Core.lua",
       "\tns.Guard(\"restriction ended\", self.ADDON_RESTRICTION_STATE_CHANGED, self)\n",
       "",
       "hunt-logic-fix: the fight ending does not probe again",
       expect="hunt-logic-fix: camelot: a probe taken in a restriction is taken again when the fight ends",
       script=S)

# The handler noting a restriction ended and doing nothing about it.
mutate("Core.lua",
       "\tif type(ask) == \"function\" and plain(ask()) == true then return end\n"
       "\tns.Guard(\"ProbeCapabilities\", ns.ProbeCapabilities)\n",
       "\tif type(ask) == \"function\" and plain(ask()) == true then return end\n",
       "hunt-logic-fix: the restriction ending probes nothing",
       expect="hunt-logic-fix: mainline: a probe taken in a restriction is taken again when the client says a restriction ended",
       script=S)

# The event never asked for: the client's word of a restriction ending (an
# encounter, a key, a match) is never heard.
mutate("Core.lua",
       "\tif caps.family == \"modern\" then\n"
       "\t\tns.Guard(\"RegisterEvent ADDON_RESTRICTION_STATE_CHANGED\"",
       "\tif false then\n"
       "\t\tns.Guard(\"RegisterEvent ADDON_RESTRICTION_STATE_CHANGED\"",
       "hunt-logic-fix: the restriction event never asked for",
       expect="hunt-logic-fix: camelot: a probe taken in a restriction is taken again when the client says a restriction ended",
       script=S)

# The event asked for on every client: the classic family does not have it, and
# asking throws.
mutate("Core.lua",
       "\tif caps.family == \"modern\" then\n"
       "\t\tns.Guard(\"RegisterEvent ADDON_RESTRICTION_STATE_CHANGED\"",
       "\tif true then\n"
       "\t\tns.Guard(\"RegisterEvent ADDON_RESTRICTION_STATE_CHANGED\"",
       "hunt-logic-fix: the restriction event asked for on every client",
       expect="hunt-logic-fix: vanilla: the restriction event is not asked for",
       script=S)

# The probe taken at the end of every fight, whatever it noted: a cost on every
# pull, for a note that needed no correcting.
mutate("Core.lua",
       "\tif not hidden then return end\n",
       "",
       "hunt-logic-fix: the probe taken whether or not it noted anything hidden",
       expect="hunt-logic-fix: camelot: a fight ending over a probe that noted nothing hidden probes nothing",
       script=S)

# The probe taken while the client still hides auras: it would only note the
# same thing again.
mutate("Core.lua",
       "\tif type(ask) == \"function\" and plain(ask()) == true then return end\n",
       "",
       "hunt-logic-fix: the probe taken while auras are still hidden",
       expect="hunt-logic-fix: camelot: nothing is probed while the client still hides auras",
       script=S)

# ------------------------------------------ a spell offered on request only
# The report: with nothing castable but a spell Automatic leaves alone (Source
# of Magic with Blessing of the Bronze switched off, Unending Breath on a Mists
# warlock without Dark Intent), BuildQueue stopped before the walk that reads
# the requests, and the one who asked was never offered it.

# The early return back as it was: no walk whenever nothing is castable.
mutate("Queue.lua",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) then\n",
       "\tif #candidates == 0 then\n",
       "hunt-logic-fix: no walk when nothing is castable, a request or not",
       expect="hunt-logic-fix: mainline: Source of Magic asked for while Blessing of the Bronze is switched off",
       script=S)

# The same, for the Mists warlock who knows only Unending Breath.
mutate("Queue.lua",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) then\n",
       "\tif #candidates == 0 then\n",
       "hunt-logic-fix: no walk when only Unending Breath is known",
       expect="hunt-logic-fix: mists: a warlock who knows only Unending Breath is asked for it (ub pls)",
       script=S)

# The walk made for everybody on every scan once a spell is offered on request
# only, whether or not anybody has asked: every passer-by judged and measured
# for nothing.
mutate("Queue.lua",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) then\n",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0) then\n",
       "hunt-logic-fix: the walk made with nobody asking",
       expect="hunt-logic-fix: mainline: nobody is walked for what only a request could be given while none stands",
       script=S)

# A request that ran out but has not been swept out of the list still standing.
mutate("Requests.lua",
       "\t\t\tif Live(request, now) then return true end\n",
       "\t\t\treturn true\n",
       "hunt-logic-fix: a lapsed request standing",
       expect="hunt-logic-fix: mainline: nobody is walked for what only a request could be given while none stands",
       script=S)
