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
