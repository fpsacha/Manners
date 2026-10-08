# "Unverified" offers and the fight that makes them: the last reading of a
# buff worn kept past a refusal of that same id while its timer runs, whose
# cast it was and a stronger rank with it, and dropped on a death (Core.lua,
# lastWorn), a refusal asked again sooner in the seconds after a fight and at
# once when one ends (REFUSAL_SECONDS, ns.ForgetRefusals), a probe made in a
# fight or while the client withheld made again as it ends, and once more a
# few seconds on (caps.probedInFight), nobody offered unverified in the first
# seconds after a fight but on a refusal for good, nor a top-up off the last
# reading (Core.lua, UNVERIFIED_SECONDS; Queue.lua), and "Only offer people
# whose buffs can be read" (filters.verifiedOnly), none of which holds back
# somebody owed or who asked. Each fault put back is caught by the scenario in
# tests/scenarios/unverified.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the last reading
mutate("Core.lua",
       "\t\t\t\t\thas, expires, mine, over = true, kept.expires, kept.mine, kept.over\n",
       "\t\t\t\t\thas = nil\n",
       "unverified: the last reading is not used",
       expect="though she was read wearing it with half an hour left", script=S)

mutate("Core.lua",
       "\t\t\tif has == nil and keptRefused and kept.expires > now then\n",
       "\t\t\tif has == nil and keptRefused then\n",
       "unverified: the last reading outlives its timer",
       expect="whose time ran out half an hour ago", script=S)

mutate("Core.lua",
       "\t\t\tif has == nil and keptRefused and kept.expires > now then\n",
       "\t\t\tif has ~= true and kept.expires > now then\n",
       "unverified: a reading of no buff leaves the last one standing",
       expect="taken for wearing the buff she was last read without", script=S)

# ------------------------------------------------ asked again
mutate("Core.lua",
       "\t\t\tand REFUSAL_SECONDS or READING_SECONDS) then\n",
       "\t\t\tand READING_SECONDS or READING_SECONDS) then\n",
       "unverified: a refusal is trusted as long as a reading",
       expect="a refusal just after a fight was trusted past a second", script=S)

mutate("Core.lua",
       "\t\t\tif entry.has == nil then perUnit[key] = nil end\n",
       "\t\t\tif false then perUnit[key] = nil end\n",
       "unverified: the fight's refusals are kept past it",
       expect="unverified: the fight's refusals are asked again as it ends", script=S)

mutate("Core.lua",
       "\tns.ForgetRefusals()\n\tif ns.ForgetUnreadPassersBy then ns.ForgetUnreadPassersBy() end\n",
       "\tif ns.ForgetUnreadPassersBy then ns.ForgetUnreadPassersBy() end\n",
       "unverified: nothing is forgotten as a fight ends",
       expect="unverified: the fight's refusals are asked again as it ends", script=S)

# ------------------------------------------------ the probe
mutate("Core.lua",
       "\tif caps.probedInFight then\n\t\tns.Guard(\"ProbeCapabilities\", ns.ProbeCapabilities)\n",
       "\tif false then\n\t\tns.Guard(\"ProbeCapabilities\", ns.ProbeCapabilities)\n",
       "unverified: a probe made in a fight is kept",
       expect="still unreadable after it", script=S)

mutate("Core.lua",
       "\t\tcaps.probedInFight = InCombatLockdown() == true or caps.aurasSecretNow == true\n",
       "\t\tcaps.probedInFight = true\n",
       "unverified: every fight probes again",
       expect="a fight with no probe in it probed again", script=S)

# ------------------------------------------------ the wait and the switch
mutate("Queue.lua",
       "(f.verifiedOnly or (src == \"withheld\" and ns.JustAfterFight(now)))",
       "(f.verifiedOnly or false)",
       "unverified: no wait after a fight",
       expect="was offered unverified as the fight ended", script=S)

mutate("Core.lua",
       "ns.UNVERIFIED_SECONDS = 5\n",
       "ns.UNVERIFIED_SECONDS = 1e9\n",
       "unverified: the wait never ends",
       expect="still unreadable, is never offered again after a fight", script=S)

mutate("Queue.lua",
       "(f.verifiedOnly or (src == \"withheld\"",
       "(false or (src == \"withheld\"",
       "unverified: the switch does nothing",
       expect="was offered unverified with the switch on", script=S)

mutate("Queue.lua",
       "\t\tif checked and reason ~= \"owed\" and reason ~= \"asked\"\n",
       "\t\tif checked and reason ~= \"asked\"\n",
       "unverified: a favour is held back unread",
       expect="was not offered back with her buffs unreadable", script=S)

# ------------------------------------------------ passers-by remembered
mutate("Queue.lua",
       "\t\tif memo.reason == \"nearby\" and memo.withheld then passing[name] = nil end\n",
       "",
       "unverified: passers-by remembered unread outlive the fight",
       expect="a passer-by remembered unread is still remembered after the fight", script=S)

mutate("Queue.lua",
       "\t\tif memo.reason == \"nearby\" and memo.withheld then passing[name] = nil end\n",
       "\t\tif memo.reason == \"nearby\" then passing[name] = nil end\n",
       "unverified: every passer-by goes with the fight",
       expect="remembered as needing the buff was let go with the fight", script=S)

mutate("Queue.lua",
       "\t\t\tor (db.filters.verifiedOnly and nearby and memo.checked and memo.known == nil)\n",
       "",
       "unverified: the switch offers the remembered unread",
       expect="remembered unread, was offered by name with the switch on", script=S)

mutate("Queue.lua",
       "\t\telseif rejected[name] == \"unread\" then",
       "\t\telseif false then",
       "unverified: an older memory offers somebody just refused",
       expect="from what was remembered of her", script=S)

# ------------------------------------------------ what the last reading keeps
mutate("Core.lua",
       "\t\t\tif has == nil and keptRefused and kept.expires > now then\n",
       "\t\t\tif has == nil and true and kept.expires > now then\n",
       "unverified: a refusal of any id keeps the last reading",
       expect="read without the buff she wore, was not offered", script=S)

mutate("Core.lua",
       "\t\tForgetAllWorn(plain(UnitGUID(unit)))\n",
       "",
       "unverified: the last reading outlives a death",
       expect="was taken for wearing the buff she died with", script=S)

mutate("Core.lua",
       "has, expires, mine, over = true, kept.expires, kept.mine, kept.over",
       "has, expires, mine, over = true, kept.expires, nil, kept.over",
       "unverified: the last reading forgets whose cast it was",
       expect="last read wearing your own cast with forty minutes left, was offered", script=S)

# A kept top-up is never offered (Queue.lua), so the timer shows only where it
# decides something else: a group member's favour paid up by your own cast.
mutate("Core.lua",
       "has, expires, mine, over = true, kept.expires, kept.mine, kept.over",
       "has, expires, mine, over = true, nil, kept.mine, kept.over",
       "unverified: the last reading forgets its timer",
       expect="last read wearing your own cast with forty minutes left, was offered", script=S)

mutate("Core.lua",
       "has, expires, mine, over = true, kept.expires, kept.mine, kept.over",
       "has, expires, mine, over = true, kept.expires, kept.mine, nil",
       "unverified: the last reading forgets a stronger rank",
       expect="last read wearing a rank stronger than yours, was offered", script=S)

mutate("Queue.lua",
       "(has and src == \"kept\")",
       "false",
       "unverified: a top-up offered off the last reading",
       expect="off what was last read of her", script=S)

# ------------------------------------------------ who is offered unread
mutate("Queue.lua",
       "\t\tif checked and reason ~= \"owed\" and reason ~= \"asked\"\n",
       "\t\tif checked and reason ~= \"owed\"\n",
       "unverified: a request is held back unread",
       expect="who asked, was not offered with her buffs unreadable", script=S)

mutate("Queue.lua",
       "\t\tif memo.reason == \"nearby\" and memo.withheld then passing[name] = nil end\n",
       "\t\tif memo.withheld then passing[name] = nil end\n",
       "unverified: the fight's end lets go of a request",
       expect="remembered unread, was let go of as the fight ended", script=S)

mutate("Queue.lua",
       "(db.filters.verifiedOnly and nearby and memo.checked and memo.known == nil)",
       "(db.filters.verifiedOnly and memo.checked and memo.known == nil)",
       "unverified: the switch lets go of a request",
       expect="remembered unread, was not offered by name with the switch on", script=S)

mutate("Queue.lua",
       "\t\tif checked and reason ~= \"owed\"",
       "\t\tif reason ~= \"owed\"",
       "unverified: the switch holds back the unread",
       expect="offering whatever they wear, Anna was not offered", script=S)

mutate("Queue.lua",
       "(src == \"withheld\" and ns.JustAfterFight(now))",
       "(ns.JustAfterFight(now))",
       "unverified: a refusal for good waits after a fight",
       expect="refused for good, was not offered unverified as the fight ended", script=S)

mutate("Queue.lua",
       "withheld = (has == nil and src == \"withheld\") or nil,",
       "withheld = (has == nil) or nil,",
       "unverified: every refusal is taken for withheld",
       expect="refused for good, was let go of as a passer-by", script=S)

mutate("Queue.lua",
       "\t\t\trejected[full] = \"unread\"\n",
       "\t\t\trejected[full] = true\n",
       "unverified: a refusal is a verdict",
       expect="was forgotten as a passer-by", script=S)

# ------------------------------------------------ the fight's end
mutate("Core.lua",
       "(cached.has == nil and not InCombatLockdown() and JustAfterFight(now))",
       "(cached.has == nil and not InCombatLockdown())",
       "unverified: every refusal out of a fight is asked again sooner",
       expect="out of any fight's wake was asked again", script=S)

# The repaint is a scan: before the fight's refusals are dropped and its end
# noted, it offers from the fight's last scan.
_FORGET = "\tns.ForgetRefusals()\n\tif ns.ForgetUnreadPassersBy then ns.ForgetUnreadPassersBy() end\n"
_REPAINT = ("\t-- A buff that landed after the fight's last tick, walked now so its favour\n"
            "\t-- is filed before the repaint below offers anybody.\n"
            "\tns.FlushOwnScan()\n"
            "\t-- Secure frames cannot be restyled or retargeted in combat, so what was\n"
            "\t-- deferred is flushed here. ApplyStyle ends in a Refresh; with nothing\n"
            "\t-- deferred, a Refresh alone takes the hold off now rather than at the next\n"
            "\t-- scan. The macro stops being built for a fight first, so that Refresh\n"
            "\t-- drops the hand-back for somebody already the target.\n"
            "\tif ns.Prompt then ns.Prompt.armedForFight = false end\n"
            "\t-- Requests held through the fight get their minute from now, before the\n"
            "\t-- Refresh below so it can offer them.\n"
            "\tns.Guard(\"requests after the fight\", ns.RequestsAfterFight)\n"
            "\tif ns.Prompt and ns.Prompt.pendingStyle then\n"
            "\t\tns.Prompt:ApplyStyle()\n"
            "\telseif ns.Prompt then\n"
            "\t\tns.Guard(\"combat release\", ns.Prompt.Refresh, ns.Prompt)\n"
            "\tend\n")
mutate("Core.lua",
       _FORGET + _REPAINT,
       _REPAINT + _FORGET,
       "unverified: the fight's end repaints before forgetting",
       expect="the repaint as the fight ended put Anna on the prompt", script=S)

mutate("Core.lua",
       "\t\tif caps.probedInFight and C_Timer and C_Timer.After then\n",
       "\t\tif false then\n",
       "unverified: no second probe after a fight",
       expect="still unreadable three seconds after the fight", script=S)

mutate("Core.lua",
       "\t\tcaps.probedInFight = InCombatLockdown() == true or caps.aurasSecretNow == true\n",
       "\t\tcaps.probedInFight = InCombatLockdown() == true\n",
       "unverified: a probe made while withheld is kept",
       expect="took for secret while the client withheld is still unreadable", script=S)
