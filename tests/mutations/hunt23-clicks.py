# Mutations for round 23's fixes in Clicks.lua: the global cooldown read from
# one of our buffs where the client has no spell 61304 (Classic Era, Burning
# Crusade Classic), and an isOnGCD read at UNIT_SPELLCAST_SENT, before the
# cooldown has started. Each undoes a fix and is caught by the scenario in
# tests/scenarios/hunt23-clicks.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ the reference
# No stand-in for 61304 at all: Era and TBC guess a second and a half after a
# healthstone.
mutate("Clicks.lua",
       "\tfor _, buff in ipairs(caps.class and ns.GetClassBuffs(caps.class) or {}) do\n",
       "\tfor _, buff in ipairs({}) do\n",
       "hunt23-clicks: no reference for the global cooldown",
       expect="hunt23-clicks: gcd-spell-61304 (vanilla)", script=S)

# The "ready in" line asking 61304 alone, so the prompt still holds a press the
# client's own bar says is free.
mutate("Clicks.lua",
       "local function GlobalCooldownLeft(now)\n\tlocal start, duration = GlobalCooldownReading()\n",
       "local function GlobalCooldownLeft(now)\n\tlocal start, duration = CooldownReading(GCD_SPELL)\n",
       "hunt23-clicks: the ready-in line asks 61304 alone",
       expect="hunt23-clicks: gcd-spell-61304 (tbc): a healthstone was drunk", script=S)

# The sweep asking 61304 alone, so it draws the guess where the client gives a
# figure.
mutate("Clicks.lua",
       "local function GcdSpan(now)\n\tlocal start, duration = GlobalCooldownReading()\n",
       "local function GcdSpan(now)\n\tlocal start, duration = CooldownReading(GCD_SPELL)\n",
       "hunt23-clicks: the sweep asks 61304 alone",
       expect="hunt23-clicks: gcd-reference (vanilla): the sweep is not the client's own figure", script=S)

# A spell's own cooldown, longer than a global one, standing for the global one.
mutate("Clicks.lua",
       "\t\t\tif start and duration <= 3 then return start, duration end\n",
       "\t\t\tif start then return start, duration end\n",
       "hunt23-clicks: a spell's own cooldown read as the global one",
       expect="eight seconds of its own cooldown stood in for the global cooldown", script=S)

# The search ending at the first buff, though it is cooling down on its own.
mutate("Clicks.lua",
       "\t\t\tif start and duration <= 3 then return start, duration end\n",
       "\t\t\tif start and duration <= 3 then return start, duration end\n\t\t\treturn nil\n",
       "hunt23-clicks: the search ends at the first buff",
       expect="hunt23-clicks: gcd-reference (the next buff, vanilla)", script=S)

# Every known buff asked though none gives a figure: a fight on Forever reads the
# client once per buff at every cooldown update.
mutate("Clicks.lua",
       "\t\t\tif not start then break end\n",
       "",
       "hunt23-clicks: every buff asked though none answers",
       expect="hunt23-clicks: gcd-reference (withheld, camelot)", script=S)

# ------------------------------------------------------------ isOnGCD at SENT
# SENT trusting an isOnGCD of false, read before the cooldown has started: with
# every figure withheld a press 0.3 s after an Intellect goes into the cooldown.
mutate("Clicks.lua",
       "\t\tif ok and type(info) == \"table\" then\n\t\t\tlocal duration = plain(info.duration)\n",
       "\t\tif ok and type(info) == \"table\" then\n\t\t\tif plain(info.isOnGCD) == false then return end\n"
       "\t\t\tlocal duration = plain(info.duration)\n",
       "hunt23-clicks: SENT trusts isOnGCD",
       expect="hunt23-clicks: notecast-isongcd-at-sent (camelot, figures withheld in a fight, isOnGCD at SENT false)",
       script=S)

# The cooldown update never asking whether the cast that armed the guess is off
# the global cooldown, so a healthstone holds the prompt for the guess.
mutate("Clicks.lua",
       "\tDropGuessOffGcd(GetTime())\n\tSyncSweep()\nend\n",
       "\tSyncSweep()\nend\n",
       "hunt23-clicks: the cooldown update does not drop the guess",
       expect="hunt23-clicks: dropped-off-gcd (camelot, figures withheld in a fight): a healthstone", script=S)

# A flag that says nothing read as an answer that the spell is off the global
# cooldown, so a press is let through a cast the client has not said anything of.
mutate("Clicks.lua",
       "\tif onGcd == nil then return end\n",
       "\tif onGcd == nil then onGcd = false end\n",
       "hunt23-clicks: an absent isOnGCD read as false",
       expect="hunt23-clicks: dropped-off-gcd (camelot, figures withheld in a fight): a spell the client says nothing about",
       script=S)

# A cast the client has said is on the global cooldown asked about at every
# cooldown update of the fight.
mutate("Clicks.lua",
       "\tif onGcd == nil then return end\n\tcastBlockedBy = nil\n",
       "\tif onGcd == nil then return end\n",
       "hunt23-clicks: a cast asked about at every cooldown update",
       expect="was asked about again", script=S)

# A guess that has run out still asked about.
mutate("Clicks.lua",
       "\tif castBlockedUntil <= now then\n\t\tcastBlockedBy = nil\n\t\treturn\n\tend\n",
       "",
       "hunt23-clicks: a spent guess asked about",
       expect="a cast whose guess had run out was asked about", script=S)
