# Mutations for resurrection (Resurrect.lua): the two switches (Core.lua,
# Options/Who.lua, Options/Advanced.lua, Options/Window/Layout.lua), the hooks
# that carry it (Core.lua IsBuffableUnit, ns.BuffInfo and ns.CanCastAnything,
# Queue.lua's walk, Prompt/Paint.lua, Prompt/Press.lua, Commands.lua), who is
# offered and who is left alone, the press and its rest, and each client's
# spells. Each is caught by the scenario in tests/scenarios/res.lua that names it.

S = "runscenarios.py"

FIRST = "res: a dead member of the group is offered your resurrection, first of everything"
FIGHT = "res: nothing is offered in a fight, and the pull leaves none on the button"
INCOMING = "res: somebody with a resurrection on the way is left alone, at once"
REACH = "res: somebody out of reach or out of sight is not offered"
PRESS = "res: a press rests them through the cast, until it is seen to fail"
CAST = "res: a cast that finished rests them until they live, and is in the ledger"
SWITCHES = "res: on for the group, off for a dead passer-by until ticked"
PAGE = "res: the switches sit on Who to buff, for a class that has a resurrection"
ALONE = "res: a class with nothing but its resurrection has a prompt for it"
RULES = "res: the never-offer list and the PvP rule hold for the dead too"

# ------------------------------------------------------------ the switches
# Off in a new profile: the group's dead are the one offer here that is on.
mutate("Core.lua",
       "\t\t\tres = true,\n",
       "\t\t\tres = false,\n",
       "res: the group's dead off in a new profile",
       expect=SWITCHES, script=S)

# On for passers-by in a new profile: nobody asked to be sent to strangers.
mutate("Core.lua",
       "\t\t\tresStrangers = false,\n",
       "\t\t\tresStrangers = true,\n",
       "res: dead passers-by on in a new profile",
       expect=SWITCHES, script=S)

# A dead passer-by offered whatever the second switch says.
mutate("Resurrect.lua",
       "\tif not inGroup and not strangers then return nil end\n",
       "",
       "res: a dead passer-by with the switch off",
       expect=SWITCHES, script=S)

# The first switch not asked: offered with it off.
mutate("Resurrect.lua",
       "local info = db and db.sources.res == true and Info() or nil\n",
       "local info = db and Info() or nil\n",
       "res: offered with the switch off",
       expect=SWITCHES, script=S)

# Shown to a class with no resurrection.
mutate("Options/Who.lua",
       "\t\thidden = function() return not (ns.Resurrect and ns.Resurrect.Has()) end,\n",
       "",
       "res: the switch shown to a mage",
       expect=PAGE, script=S)

# The second switch shown while the first is off, when it offers nobody.
mutate("Options/Who.lua",
       "return not (ns.Resurrect and ns.Resurrect.Has() and S().res) end",
       "return not (ns.Resurrect and ns.Resurrect.Has()) end",
       "res: the second switch shown with the first off",
       expect=PAGE, script=S)

# Drawn level with the first, as a source of its own.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.resStrangers\", indent = true },\n",
       "\t\t\t\t\t{ \"who.resStrangers\" },\n",
       "res: the second switch is not a step in",
       expect=PAGE, script=S)

# Search cannot say which switch shows it.
mutate("Options/Window/Layout.lua",
       "\t\t[\"who.resStrangers\"] = \"who.res\",\n",
       "",
       "res: search is not told the second switch's parent",
       expect=PAGE, script=S)

# The page's reset leaves both as they were.
mutate("Options/Advanced.lua",
       "\t\t\"sources.res\", \"sources.resStrangers\",\n",
       "",
       "res: the page's reset leaves the switches",
       expect=PAGE, script=S)

# ------------------------------------------------------------ the hooks
# The walk hands over nobody: the dead are nobody again.
mutate("Core.lua",
       "\t\tif ns.deadSeen then ns.deadSeen[#ns.deadSeen + 1] = unit end\n",
       "",
       "res: the walk hands over no dead",
       expect=FIRST, script=S)

# The spell's own answer not given: no name to cast by.
mutate("Core.lua",
       "\tif buff.res then return buff.info end\n",
       "",
       "res: a resurrection has no name to cast by",
       expect=FIRST, script=S)

# A resurrection learned is not something to cast: no prompt for a monk.
mutate("Core.lua",
       "\tif caps.res and ns.Resurrect and ns.Resurrect.Wanted() then return true end\n",
       "",
       "res: a resurrection alone is nothing to cast",
       expect=ALONE, script=S)

# ...nor learned with the probe, which is when that question is first asked.
mutate("Resurrect.lua",
       "\t\tlocal result = probe(...)\n\t\tRes.Learn()\n",
       "\t\tlocal result = probe(...)\n",
       "res: not learned with the probe",
       expect=ALONE, script=S)

# The walk never says it ran, so the group is walked a second time each scan.
mutate("Queue.lua",
       "\tif ns.deadSeen then ns.deadSeen.walked = true end\n",
       "",
       "res: the group is walked twice a scan",
       expect="res: a scan with nobody dead asks the client nothing more", script=S)

# The reason line a member of the group has, for somebody dead.
mutate("Prompt/Paint.lua",
       "\tif entry.res then return ns.Resurrect.Reason(entry) end\n",
       "",
       "res: the reason line does not say dead",
       expect="res: the reason line says they are dead", script=S)

# The press filed as a buff's: parked for the settle, a favour repaid by it.
mutate("Prompt/Press.lua",
       "\tif S.current.res then return ns.Resurrect.Pressed(S.current) end\n",
       "",
       "res: the press filed as a buff's",
       expect=PRESS, script=S)

# /manners debug says nothing of it.
mutate("Commands.lua",
       "\t\t-- Why a resurrection is, or is not, on the prompt (Resurrect.lua).\n"
       "\t\tfor _, line in ipairs(ns.ResurrectLines and ns.ResurrectLines(true) or {}) do self:Print(\"  \" .. line) end\n",
       "\t\t-- Why a resurrection is, or is not, on the prompt (Resurrect.lua).\n",
       "res: debug says nothing of a resurrection",
       expect="res: /manners debug says what is offered and who rests", script=S)

# ------------------------------------------------------------ who is offered
# Behind your target and everybody owed, as a member of the group is.
mutate("Resurrect.lua",
       "local PRIORITY = -1\n",
       "local PRIORITY = 5\n",
       "res: the dead are not first",
       expect=FIRST, script=S)

# Offered under the combat lockdown.
mutate("Resurrect.lua",
       "\tif InCombatLockdown() or (prompt and prompt.armedForFight == true)\n",
       "\tif (prompt and prompt.armedForFight == true)\n",
       "res: offered under the lockdown",
       expect=FIGHT, script=S)

# The pull's own repaint arms it, frozen for the fight.
mutate("Resurrect.lua",
       "\tif InCombatLockdown() or (prompt and prompt.armedForFight == true)\n",
       "\tif InCombatLockdown() or false\n",
       "res: the pull freezes a resurrection",
       expect=FIGHT, script=S)

# Offered while the game says you are fighting, ahead of the lockdown.
mutate("Resurrect.lua",
       "\t\tor (fighting and plain(fighting(\"player\")) == true) then\n",
       "\t\tthen\n",
       "res: offered while the game says fighting",
       expect=FIGHT, script=S)

# Two healers sent to the same body.
mutate("Resurrect.lua",
       "\tif incoming and plain(incoming(unit)) == true then\n",
       "\tif false then\n",
       "res: offered with a resurrection on the way",
       expect=INCOMING, script=S)

# ...and the prompt left on her for its hold, after the scan let her go.
mutate("Resurrect.lua",
       "\t\t\tns.MarkAttempted(old.name, old.buff.key, RETRY_SECONDS)\n",
       "",
       "res: the prompt holds somebody let go",
       expect=INCOMING, script=S)

# A spirit running back is offered, wherever its body lies.
mutate("Resurrect.lua",
       "\tif ghost and plain(ghost(unit)) == true then\n",
       "\tif false then\n",
       "res: a spirit is offered",
       expect="res: somebody who released their spirit is left alone", script=S)

# A hunter feigning death is taken for dead.
mutate("Resurrect.lua",
       "\tif feign and plain(feign(unit)) == true then return nil end\n",
       "",
       "res: Feign Death taken for death",
       expect="res: a hunter lying in Feign Death is not dead", script=S)

# Offered to somebody measured out of range.
mutate("Resurrect.lua",
       "\t\tif person.reach == false then\n",
       "\t\tif false then\n",
       "res: offered out of range",
       expect=REACH, script=S)

# ...and to somebody out of sight.
mutate("Resurrect.lua",
       "\tif visible and plain(visible(unit)) == false then\n",
       "\tif false then\n",
       "res: offered out of sight",
       expect=REACH, script=S)

# Offered without the mana for it.
mutate("Resurrect.lua",
       "\t\tif usable == false and noMana == true then\n\t\t\tcounts.mana",
       "\t\tif false then\n\t\t\tcounts.mana",
       "res: offered without the mana",
       expect="res: not offered without the mana for it", script=S)

# The never-offer list not asked.
mutate("Resurrect.lua",
       "\tif ns.IsNeverOffered(name) then return nil end\n",
       "",
       "res: offered to somebody on the never-offer list",
       expect=RULES, script=S)

# The PvP rule not asked.
mutate("Resurrect.lua",
       "\tif flagged then\n",
       "\tif false then\n",
       "res: offered to somebody flagged for PvP",
       expect=RULES, script=S)

# One dead member offered the cast for the whole group.
mutate("Resurrect.lua",
       "\t\tif waiting >= 2 and not",
       "\t\tif waiting >= 1 and not",
       "res: the group's cast for one",
       expect="res: several dead are offered the one cast for the group", script=S)

# ------------------------------------------------------------ the press
# No rest for the length of the cast: offered again two seconds into it.
mutate("Resurrect.lua",
       "\t\t\tRest(pending, CAST_SECONDS)\n",
       "",
       "res: no rest while the cast runs",
       expect=PRESS, script=S)

# A cast seen to fail gives nobody back.
mutate("Resurrect.lua",
       "\t\tRest(pending, RETRY_SECONDS)\n",
       "",
       "res: a failed cast gives nobody back",
       expect=PRESS, script=S)

# Another cast of the spell, refused, ends the rest of the one under way.
mutate("Resurrect.lua",
       "\tif pending.guid and guid and guid ~= pending.guid then return end\n",
       "",
       "res: another cast's refusal ends the rest",
       expect=PRESS, script=S)

# No rest once the cast has finished: offered again while they answer.
mutate("Resurrect.lua",
       "\t\tRest(pending, ACCEPT_SECONDS)\n",
       "\t\tRest(pending, RETRY_SECONDS)\n",
       "res: no rest after the cast",
       expect=CAST, script=S)

# ...or a rest with no end, for somebody who never answered.
mutate("Resurrect.lua",
       "ANSWER_SECONDS, CAST_SECONDS, ACCEPT_SECONDS, RETRY_SECONDS = 2, 12, 65, 2\n",
       "ANSWER_SECONDS, CAST_SECONDS, ACCEPT_SECONDS, RETRY_SECONDS = 2, 12, 600, 2\n",
       "res: a rest that outlasts the question",
       expect=CAST, script=S)

# Standing up does not end it: dead again, and not offered.
mutate("Resurrect.lua",
       "\t\t\tns.MarkAttempted(name, KEY, 0)\n",
       "",
       "res: standing up does not end the rest",
       expect=CAST, script=S)

# Nothing in the favour ledger.
mutate("Resurrect.lua",
       "\t\tns.TellLedger(\"Settled\", pending.mass",
       "\t\tns.TellLedger(\"Nothing\", pending.mass",
       "res: the ledger is not told",
       expect=CAST, script=S)

# A line said over the dead: the entry carries a range for it to be armed on.
mutate("Resurrect.lua",
       "\t\t\t\treach = person.reach,\n",
       "\t\t\t\treach = person.reach, ranged = person.reach,\n",
       "res: a line said for a resurrection",
       expect="res: nothing is said for a resurrection", script=S)

# ------------------------------------------------------------ the spells
# Rebirth for Forever's druid: a fight's spell, with a reagent and half an hour.
mutate("Resurrect.lua",
       "\t\tDRUID = { single = { 1237951, 1237950, 1237949, 1237948, 437138 } },\n",
       "\t\tDRUID = { single = { 20748, 20747, 20742, 20739, 20484 } },\n",
       "res: Rebirth offered after a fight",
       expect="res: each client has its own spells, and none that is for a fight", script=S)
