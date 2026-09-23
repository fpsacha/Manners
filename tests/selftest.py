"""Prove the harness still detects the fault classes that actually happened,
by reintroducing each one, running, and putting the file back.

A suite that cannot go red proves nothing, so this is run whenever the addon
is restructured -- a refactor can quietly move the code a check depends on.

Each mutation names the check that is supposed to catch it, and that check has
to be the one that fires. Inferring "caught" from the whole run going red says
only that the tree is broken, which a mutation guarantees: a bug reintroduced
in the prompt and noticed by a scenario about debts read as a pass, and the
column then measured nothing but whether the file still loaded.
"""
import subprocess, shutil, sys, os

DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(DIR, "tests")


SUITES = ("runharness.py", "runscenarios.py")


def run(script):
    r = subprocess.run([sys.executable, os.path.join(TESTS, script)],
                       capture_output=True, text=True)
    return r.stdout


def verdict(out):
    """The suite's own verdict line, and whether it is a clean one.

    validate.py says it differently from the two Lua suites, and a mutation
    aimed at it has to be able to come back clean -- otherwise its "caught"
    would rest on a verdict line this could not read at all."""
    lines = [l for l in out.split("\n")
             if l.startswith(("errors:", "failures:", "RESULT:"))]
    line = lines[0] if lines else "?"
    return line, line in ("errors: 0", "failures: 0", "RESULT: all checks passed")


def tally(script):
    return verdict(run(script))


def findings(out):
    """The individual complaints, which is where the attribution lives.

    Both suites print one indented line per failure and then a count. The old
    version of this tested `line.strip().startswith("  ")` on a string it had
    just stripped, so it was false for every line ever printed and no mutation
    has ever named the check that caught it -- the evidence the CAUGHT column
    claims to rest on was never once read.
    """
    return [l.rstrip() for l in out.split("\n") if l.startswith("  ") and l.strip()]


dead_anchors = []
missed = []
misattributed = []


def mutate(filename, old, new, label, expect, script="runharness.py"):
    """Reintroduce one bug and require `expect` to be the check that objects.

    `expect` is matched against the failing lines, case-insensitively: a
    scenario's name, or the harness step that throws. Anything else firing as
    well is fine and often unavoidable -- one broken function takes several
    paths down with it -- but the named check going quiet is a failure even
    when the run is red, because a red run proves nothing about this bug.
    """
    path = os.path.join(DIR, filename)
    backup = path + ".selftest-backup"
    shutil.copy2(path, backup)
    try:
        s = open(path, encoding="utf-8").read()
        if old not in s:
            # A check that is no longer wired to anything reports success for
            # the rest of time, which is worse than a failing one. Recorded so
            # the run itself fails rather than printing a warning nobody reads.
            dead_anchors.append(label)
            print("%-44s *** ANCHOR GONE -- check is no longer live ***" % label)
            return
        open(path, "w", encoding="utf-8", newline="\n").write(s.replace(old, new, 1))
        out = run(script)
        _, clean = verdict(out)
        complaints = findings(out)
        hits = [c for c in complaints if expect.lower() in c.lower()]

        if clean:
            missed.append(label)
            print("%-44s *** MISSED ***" % label)
        elif not hits:
            # Red, but not about this. The bug was reintroduced and something
            # else fell over -- so this line proves that other thing is fragile
            # and nothing whatever about the check it claims to exercise.
            misattributed.append((label, expect, complaints[:3]))
            print("%-44s *** WRONG CHECK -- %r did not fire ***" % (label, expect))
            for c in complaints[:3]:
                print("      instead: " + c.strip()[:96])
        else:
            print("%-44s CAUGHT  (%d)" % (label, len(complaints)))
            print("      " + hits[0].strip()[:96])
    finally:
        shutil.move(backup, path)


print("baseline:")
# Every mutation below is judged by the suite going red. Against a tree that is
# already red they all report CAUGHT without proving a thing, and this file then
# signs off on checks it never exercised -- the same failure as a dead anchor,
# arriving from the other direction. So the baseline is a gate, not a note.
dirty = []
for script in SUITES:
    line, clean = tally(script)
    print("  %-20s %s" % (script, line))
    if not clean:
        dirty.append(script)
if dirty:
    print()
    print("RESULT: the tree is already failing (" + ", ".join(dirty) + "),"
          " so no mutation below would mean anything")
    sys.exit(1)
print()

# 1. a name local to another file, called from this one -- the `plain` bug
mutate("Prompt.lua",
       "ns.PickPhrase(entry,",
       "PickPhrase(entry,",
       "cross-file local call (the `plain` bug)",
       expect="Prompt:Refresh")

# 2. an event this client does not have -- the scanner-never-started bug
mutate("Core.lua",
       '"SPELLS_CHANGED",',
       '"LEARNED_SPELL_IN_TAB",',
       "unknown event (scanner never started)",
       expect="registered unknown event")

# 3. a misspelled API, the general case
mutate("Core.lua",
       "local maxMana = plain(UnitPowerMax(unit, MANA))",
       "local maxMana = plain(UnitPowerMaxx(unit, MANA))",
       "misspelled WoW API",
       expect="BuildQueue")

# 4. a setting left unvalidated -- a stale profile falls through every branch
mutate("Core.lua",
       '\toneOf(p, "style", { glass = true, framed = true, minimal = true }, "glass")',
       "",
       "unvalidated enum setting",
       expect="garbage profile",
       script="runscenarios.py")

# 5. the stale-macro bug: an emptied queue leaving the last person armed
mutate("Prompt.lua",
       """		for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit",
			"type2", "type3", "type4", "type5" }) do
			button:SetAttribute(attribute, nil)
		end
		appliedKey = nil""",
       """		if appliedKey ~= nil then
			for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
				"type", "macrotext", "spell", "unit",
				"type2", "type3", "type4", "type5" }) do
				button:SetAttribute(attribute, nil)
			end
			appliedKey = nil
		end""",
       "stale macro on an emptied queue",
       expect="emptied queue disarms",
       script="runscenarios.py")

# 6. the macro rebuilt from scratch on every repaint -- the reason appliedKey
#    exists at all. A dead optimisation is not a bug, but a dead check is: this
#    one went unnoticed for three releases while the name sat unread in four
#    assignments.
mutate("Prompt.lua",
       "	if key == appliedKey then return end",
       "	if false then return end",
       "macro re-armed on every repaint",
       expect="the macro is armed once per candidate",
       script="runscenarios.py")

# 7. a debt written in GetTime() units, which mean nothing after a reload
mutate("Core.lua",
       "	local wall = plain(time and time())",
       "	local wall = GetTime()",
       "debts saved on a clock that restarts",
       expect="debts survive a reload",
       script="runscenarios.py")

# 8. the aura baseline reused without being emptied. The reuse is a deliberate
#    optimisation -- this runs on every UNIT_AURA -- and the wipe is the only
#    thing that keeps it from becoming a list of everything you have ever held.
mutate("Core.lua",
       "function ns.ScanOwnBuffs()\n\twipe(present)\n",
       "function ns.ScanOwnBuffs()\n",
       "an aura baseline that never forgets",
       expect="the aura baseline forgets what fell off",
       script="runscenarios.py")

# 9. the one line that puts the console in SavedVariables. The file says in two
#    places that a session can be read off disk afterwards; without this it
#    cannot, and nothing about that is visible in game.
mutate("Core.lua",
       "\tMannersDB.console = ns.console\n",
       "",
       "the console never reaching the disk",
       expect="what the console printed is on disk",
       script="runscenarios.py")

# 10. the aura baseline taken from a single scan. This is the loading-screen
#     bug: PLAYER_ENTERING_WORLD wipes the baseline and scans in the same
#     breath, so the count-based gate has nothing to compare against, and a
#     client that blacks the list out with plain silence primes an empty
#     baseline off a list it was never shown -- then announces every buff the
#     player is carrying as a favour when the list reads back. It cannot be
#     caught by recognising the refusal: a plain nil is also exactly what an
#     empty slot looks like, so only a second scan agreeing catches it.
mutate("Core.lua",
       "\t\tif agrees then\n",
       "\t\tif true then\n",
       "an aura baseline primed off one scan",
       expect="a loading screen cannot invent a favour",
       script="runscenarios.py")

# 11. and the same mistake at the other end of the scan. A refusal of the
#     trailing slots leaves no readable aura behind the silence, so there is no
#     evidence of it anywhere in the reading; pruning on that one scan drops
#     precisely the auras it failed to read and invents a favour out of each of
#     them the moment they come back.
mutate("Core.lua",
       "\t\t\tif present[instanceId] ~= key and lastPresent[instanceId] ~= key then\n",
       "\t\t\tif present[instanceId] ~= key then\n",
       "an aura baseline pruned off one scan",
       expect="a refusal at the end of the list cannot invent favours",
       script="runscenarios.py")

# 12. one line, and it looks like a tidy-up: the evidence the scan collects is
#     recorded for /manners debug either way, so dropping the early return
#     changes nothing a reader can see. It changes what counts as a reading. A
#     scan the client refused outright currently never becomes one of the two
#     that have to agree, so a recognisable blackout can last all day without
#     ever agreeing with itself; without this it corroborates its own refusal on
#     the second scan and empties the baseline.
mutate("Core.lua",
       "\t\tif not primed then ScheduleSettle() end\n\t\treturn\n\tend\n",
       "\t\tif not primed then ScheduleSettle() end\n\tend\n",
       "a refusal that corroborates itself",
       expect="a refusal cannot corroborate itself",
       script="runscenarios.py")

# 13. the paladin bug, at its root: a policy about who deserves an offer,
#     written as an aura reading. "Offer them anyway because we owe them" was
#     spelled as "the client says they have none of these", and PickBuffFor
#     believed it -- so the blessing somebody was carrying read back as absent
#     and the walk offered the next one down, over the top of it.
mutate("Core.lua",
       "\t\tlocal function auraState(buff)\n",
       "\t\tlocal function auraState(buff)\n\t\t\tif isOwed then return false end\n",
       "a policy disguised as an aura reading",
       expect="a debt does not walk a paladin off the blessing they hold",
       script="runscenarios.py")

# 14. and the same walk-off by the other door. A blessing on cooldown is one
#     that was offered moments ago; stepping past it to the next one replaces
#     what the last click gave. The carve-out let a readable client do exactly
#     that, on the strength of an aura reading taken before the cast.
mutate("Core.lua",
       "\t\tif onCooldown then return nil, nil end\n",
       "\t\tif onCooldown and not allRead then return nil, nil end\n",
       "a blessing replaced while it is on cooldown",
       expect="a paladin is not walked off the blessing just given",
       script="runscenarios.py")

# 15. one pending slot, overwritten without a word. Everything the buried press
#     wrote on the assumption it landed stays standing, with nothing left that
#     could ever take it back.
mutate("Prompt.lua",
       "\t\tns.AbandonPendingClick()\n",
       "",
       "a pending click discarded silently",
       expect="a second press does not bury the first",
       script="runscenarios.py")

# 16. the regression: any error the game raises settling our click outright.
#     The record is thrown away, so the cast that really did go out a frame
#     later has nothing left to settle and the favour stays owed.
mutate("Core.lua",
       """	RewindClick(pending)
	return pending.name
end""",
       """	RewindClick(pending)
	ns.pendingClick = nil
	return pending.name
end""",
       "a parked record dropped by an error",
       expect="an unrelated error does not throw the record away",
       script="runscenarios.py")

# 16b. and the other half of the same decision: the error takes the per-buff
#      cooldown and the rotation pointer back on a doubt, and deliberately
#      leaves the record parked. When the cast turns up anyway, nothing put
#      either back -- so a buff that was delivered was offered again two
#      seconds later.
mutate("Core.lua",
       """	ns.MarkAttempted(pending.name, pending.buffKey)
	if pending.buffKey and ns.RotatesBuffs() then
		ns.lastGave[pending.name] = pending.buffKey
	end
""",
       "",
       "a rewind outliving the doubt behind it",
       expect="an unrelated error does not throw the record away",
       script="runscenarios.py")

# 17. a recipient the client would not name, read as "nothing contradicting who
#     it went to". Any cast of the offered buff inside the window then repays
#     that person, whoever actually received it.
mutate("Core.lua",
       "\telseif pending.targeted then\n",
       "\telseif true then\n",
       "a debt settled on a cast nothing connects to it",
       expect="an unattributed cast settles only what the macro aimed at",
       script="runscenarios.py")

# 18. user-typed text handed to gsub as a replacement, where % is an escape.
#     "10% left" in the top-up wording throws on every repaint.
mutate("Core.lua",
       '\treturn ((text or ""):gsub(token, function() return value or "" end))\n',
       '\treturn ((text or ""):gsub(token, value or ""))\n',
       "typed text used as a gsub replacement",
       expect="a per-cent sign in the wording does not stop the prompt",
       script="runscenarios.py")

# 19. the strobe. The queue is rebuilt from scratch 2.5 times a second and the
#     top of it churns in any crowd -- usually because the person already on the
#     panel dropped out of one scan, not because somebody better arrived. Without
#     the hold the panel follows every one of those, with the cross-fade and the
#     sound behind it.
mutate("Prompt.lua",
       "	if not HoldStillStands(GetTime()) then return top end\n",
       "	if true then return top end\n",
       "the prompt strobing on a churning queue",
       expect="handed the panel to somebody no more deserving",
       script="runscenarios.py")

# 20. and the other half of it: one empty scan taking the prompt down, so the
#     next scan 0.4s later puts it back with the entrance animation replayed.
mutate("Prompt.lua",
       "			if now - emptyAt < EMPTY_FUSE_SECONDS then return end\n",
       "",
       "an empty scan hiding the prompt at once",
       expect="one empty scan took the prompt down",
       script="runscenarios.py")

# 20b. and the press disagreeing with the panel while that fuse burns: the
#      prompt is visible and naming somebody, and re-resolving to nobody here
#      disarms it -- so the click does nothing and says nothing, which is the
#      silent failure the fuse was added to avoid, arriving by the other door.
mutate("Prompt.lua",
       "		if not top and current and not Retired(current, now) and named == current.name then\n",
       "		if false then\n",
       "a press that disarms a visible prompt",
       expect="a press while the prompt was still naming Ana disarmed it",
       script="runscenarios.py")

# 20c. the count of who else is waiting, read off the queue's length instead of
#      counted. The pick is not always queue[1] -- a tie is kept with the
#      current candidate, and a held one is not in the queue at all -- so this
#      is short by one for exactly the people the hold exists for.
mutate("Prompt.lua",
       "	self:Paint(top, others)\n",
       "	self:Paint(top, #queue - 1)\n",
       "a waiting count read off the queue order",
       expect="read off the queue's order",
       script="runscenarios.py")

# 20d. and the same assumption in the list itself. Skipping queue[1] rather than
#      the person actually on the panel drops the held-off candidate out of the
#      list entirely, and lists the panel's own person when the pick is not
#      queue[1]. It also stops the hold ever being renewed, which is the part
#      that looks harmless.
mutate("Prompt.lua",
       """		if entry.name == top.name then
			inQueue = true
		else
			others = others + 1""",
       """		if false then
			inQueue = true
		else
			others = others + 1""",
       "the panel's own person listed as waiting",
       expect="the person on the panel is listed again as somebody waiting",
       script="runscenarios.py")

# 21. the sound tied to the name on the panel changing, which is exactly the
#     thing that churns. A panel swapping a name can be looked away from.
mutate("Prompt.lua",
       """	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed")
		and not (lastSoundAt and (now - lastSoundAt) < SOUND_FLOOR_SECONDS) then""",
       """	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed") then""",
       "the alert sound following the churn",
       expect="the alert sound has a floor under it",
       script="runscenarios.py")

# 22. a tick over a cast nobody confirmed. The settle path is careful about the
#     difference between the client naming the person we aimed at and the client
#     refusing to name anybody, and this is the panel throwing that care away --
#     which is worse than the silence it replaced, because it is believed.
mutate("Core.lua",
       '\tlocal how = inferred and SETTLE_INFERENCE[inferred]\n'
       '\tShowOutcome(how and "sent" or "cast", pending.name, how and how.sub)\n',
       '\tShowOutcome("cast", pending.name)\n',
       "a tick over an unconfirmed cast",
       expect="the panel claimed the buff landed on somebody the client never named",
       script="runscenarios.py")

# 23. the game's own reason for the failure never reaching the panel. It is
#     localised, it is frequently the only thing that says *why* -- out of
#     range, line of sight -- and it went nowhere unless click debugging was on.
mutate("Core.lua",
       '\t\tShowOutcome("failed", failed, type(message) == "string" and message or nil)\n',
       "",
       "the game's reason kept off the panel",
       expect="an error inside the click window left the panel looking like a successful cast",
       script="runscenarios.py")

# 24. the combat hold. The macro is frozen at whoever was on the button when the
#     fight started; without this the panel goes on painting that at full
#     brightness with a live queue listed underneath it.
mutate("Prompt.lua",
       "		self:SetCombatHold(true)\n",
       "",
       "a frozen prompt that still looks live",
       expect="the panel kept full brightness over a frozen target",
       script="runscenarios.py")

# 25. and the tooltip over it, which is the most detailed and most convincing
#     thing the prompt says about a macro that cannot follow anything.
mutate("Prompt.lua",
       '		if InCombatLockdown() then return end\n		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       '		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       "a tooltip describing a frozen macro",
       expect="the tooltip described a frozen macro in detail",
       script="runscenarios.py")

# 26. the spoken line re-rolled per repaint and again on the press, so the line
#     quoted in the tooltip was never the line that went out. The cache looks
#     like an optimisation and is the only thing making the quote true.
mutate("Prompt.lua",
       "	if phraseKey ~= key then\n",
       "	if true then\n",
       "the tooltip quoting a line it will not cast",
       expect="the tooltip quotes the line that will actually run",
       script="runscenarios.py")

# 27. queue rows lying on the world with no background: unreadable on anything
#     bright, absent on anything dark.
mutate("Prompt.lua",
       "	queueBack:SetShown(back)\n",
       "	queueBack:SetShown(false)\n",
       "a queue list with no background",
       expect="the rows are still lying on the world with no background",
       script="runscenarios.py")

# 28. and the same list hanging below a prompt that now sits just above the
#     action bars, which runs it off the bottom of the screen.
mutate("Prompt.lua",
       "	queueAbove = QueueGoesAbove()\n",
       "	queueAbove = false\n",
       "a queue list that runs off the screen",
       expect="still hangs its list below itself",
       script="runscenarios.py")

# 29. an icon larger than the panel it sits in. The slider ran to 64 against a
#     height that runs down to 20.
mutate("Core.lua",
       "	if p.iconSize > iconMax then p.iconSize = iconMax end",
       "",
       "an icon taller than the prompt",
       expect="the icon cannot be bigger than the panel",
       script="runscenarios.py")

# 30. the prompt back in the middle of the play area: a panel that eats mouse
#     clicks, over whatever you are looking at, movable only by unlock-drag-lock.
mutate("Core.lua",
       """			point = "BOTTOM",
			relPoint = "BOTTOM",
			x = 0,
			y = 300,""",
       """			point = "CENTER",
			relPoint = "CENTER",
			x = 0,
			y = -140,""",
       "the prompt parked over the play area",
       expect="the prompt still defaults to the middle of the play area",
       script="runscenarios.py")

# 31. preview timing out while the options window is open, which is the only
#     time it is any use -- and the reason the prompt could not be styled in a
#     city at all.
mutate("Prompt.lua",
       "		local styling = ns.OptionsOpen and ns.OptionsOpen()\n",
       "		local styling = false\n",
       "preview dying while it is being used",
       expect="preview survives the options window being open",
       script="runscenarios.py")

# 32. two controls sharing an order number. AceConfig breaks the tie on the
#     option's *name*, so the page renders perfectly and puts a slider under a
#     dropdown it has nothing to do with -- which is what "...after this long"
#     did under "If they already have the buff" for four releases.
mutate("Options.lua",
       "order = 23.5,",
       "order = 23,",
       "two controls at the same order",
       expect="are both at order",
       script="runscenarios.py")

# 33. a control moved between tabs taking its key with it. The sound settings
#     now sit beside the flash under an option key of their own, and reading the
#     profile field off that key instead of naming it is a silent settings reset
#     for everybody who already had a sound chosen.
mutate("Options.lua",
       """						set = function(_, value)
							SND().file = value""",
       """						set = function(info, value)
							SND()[info[#info]] = value""",
       "a moved control losing its stored value",
       expect="ticking play a sound makes a sound",
       script="runscenarios.py")

# 34. the unit dropped back out of a slider's name. Four of the five are seconds
#     and the fifth is minutes, and an AceConfig range has nowhere else to put
#     it: "Remember a buff for: 120" and "Top up when under: 5" read as the same
#     kind of number.
mutate("Options.lua",
       "Remember a buff for (seconds)",
       "Remember a buff for",
       "a time slider showing a bare number",
       expect="the time sliders say what they are counting",
       script="runscenarios.py")

# 35. the sound going off for everybody again while the flash stays choosy. The
#     two are one job and were two tabs apart, which is how they came to
#     disagree about who is worth interrupting for.
mutate("Prompt.lua",
       '		and (not db.sound.owedOnly or top.reason == "owed")\n',
       "",
       "the sound alerting for passers-by",
       expect="the sound is as choosy as the flash",
       script="runscenarios.py")

# 36. the per-spell switches not consulted. The walk offers a class's whole
#     list, and the only way to say "not that one" used to be pinning a single
#     spell -- which switches the walk off altogether.
mutate("Core.lua",
       """		if ns.IsBuffKnown(buff)
			and (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))
			and (not buff.neverAuto or pinned == buff.key) then""",
       """		if ns.IsBuffKnown(buff)
			and (not buff.neverAuto or pinned == buff.key) then""",
       "a spell switched off and offered anyway",
       expect="the owed fallback obeys the same filters",
       script="runscenarios.py")

# 37. the page explaining somebody else's class. The old line named Wisdom and
#     Might -- the one class whose automatic pick depends on who is standing
#     there -- so a priest read an explanation of a paladin's spells, and with
#     the walk shipped it does not describe even the paladin any more.
mutate("Options.lua",
       """	local text = ("Automatic offers the first of these they are missing, in this order: %s.")
		:format(list)""",
       '	local text = "Automatic uses the first buff you have learned."',
       "the auto note naming no spells at all",
       expect="the explanation of Automatic does not name",
       script="runscenarios.py")

# 38. three sources switched off, which is a prompt that can never appear and
#     is indistinguishable from a broken addon.
mutate("Options.lua",
       "					return s.owed or s.group or (s.strangers and not OnlyReachesGroup())",
       "					return true",
       "no warning for a queue that can never fill",
       expect="all three sources are off and the page says nothing",
       script="runscenarios.py")

# 39. and the quietest of them: a pinned spell you have not learned. The pin is
#     the only spell considered, so nobody is offered anything at all -- and it
#     is deliberately not reset for you, because a failed spell probe must not
#     rewrite a setting.
mutate("Options.lua",
       'hidden = function() return ns.PinnedBuff() == nil end,',
       "hidden = function() return true end,",
       "no warning for a pin that stops everything",
       expect="a pinned spell you have not learned stops everything",
       script="runscenarios.py")

# 39b. a toggle with nothing behind it. Battle Shout is cast on yourself and
#      heard by your party, so the queue turns down everybody outside the group
#      before the strangers toggle is ever read -- and a control that does
#      nothing reads as a feature that is broken.
mutate("Options.lua",
       "				hidden = OnlyReachesGroup,\n",
       "",
       "a toggle offered to a class it cannot help",
       expect="a switch with nothing behind it is not shown",
       script="runscenarios.py")

# 40. the target rule ignoring the switch that was added for it. It is a
#     preference about somebody else's queue order, not a fact about them.
mutate("Core.lua",
       '		if unit == "target" and db.priority.target',
       '		if unit == "target"',
       "the target rule with no way off",
       expect="the target rule can be switched off",
       script="runscenarios.py")

# 41. debts written to disk by a session that was told to forget them, and
# 42. read back by one that was. The file outlives the setting -- a profile is
#     switched between logins, or changed on another character sharing it -- so
#     both ends have to honour it.
mutate("Core.lua",
       """	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil""",
       "	local now, out = GetTime(), nil",
       "debts saved after being switched off",
       expect="debts can be told not to outlive the session",
       script="runscenarios.py")

mutate("Core.lua",
       """	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()""",
       "	local now = GetTime()",
       "debts restored after being switched off",
       expect="a session told to forget does not restore",
       script="runscenarios.py")

# 43. the errors the addon already caught, back to being invisible on the one
#     page somebody opens when nothing is working.
mutate("Options.lua",
       "hidden = function() return #ns.errors == 0 end,",
       "hidden = function() return true end,",
       "caught errors kept off the page",
       expect="something broke and the page still shows nothing",
       script="runscenarios.py")

# 44. and the build number out of the block that exists to be pasted into a
#     report -- the first question every report gets, asked of the one screen
#     that could not answer it.
mutate("Options.lua",
       'local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }',
       'local lines = { "Manners" }',
       "a bug report with no build number",
       expect="the bug report leaves out",
       script="runscenarios.py")

# 45. the combat notice. Every control on the Prompt tab is a secure attribute
#     or a texture on a secure frame, and ApplyStyle returns without doing
#     anything for the length of a fight.
#     Anchored with the notice's own wording: the When you click tab has one
#     of these as well now, and it comes first in the file.
mutate("Options.lua",
       "hidden = function() return not InCombatLockdown() end,\n"
       "\t\t\t\t\t\tname = \"|cffffd100In combat.|r Blizzard freezes secure frames",
       "hidden = function() return true end,\n"
       "\t\t\t\t\t\tname = \"|cffffd100In combat.|r Blizzard freezes secure frames",
       "a frozen tab that looks like a working one",
       expect="in combat, and the tab reads as though everything on it works",
       script="runscenarios.py")

# 46. and the repaint that takes it down again. That `hidden` is only ever asked
#     while AceConfig is drawing, so without this the notice stands over
#     controls that work again for as long as the window stays open.
mutate("Core.lua",
       """	-- And the notice on the Prompt tab comes off. Without this it stands over
	-- controls that work again, which is the same lie as the one it was added
	-- to stop, told the other way round.
	ns.RepaintOptions()
""",
       "",
       "a combat notice that never comes down",
       expect="leaving combat left the notice standing",
       script="runscenarios.py")

# 47. the confirmation on the one control that destroys typed text. Reset
#     position -- undone by dragging the prompt back -- had one; loading a
#     phrase set, which overwrites a box somebody filled by hand with no undo
#     anywhere in the addon, did not.
mutate("Options.lua",
       """						confirm = function(_, value)
							return ("Replace everything in the box below with the %s lines?"):format(
								(ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label)
									or tostring(value))
						end,
""",
       "",
       "hand-written phrases wiped without asking",
       expect="the destructive control is the one that asks",
       script="runscenarios.py")

# 48. the caster read at the announcement instead of at the sighting. One line,
#     and it looks like a memo that saves four unit lookups: the identity is
#     read either way. What it saves is the identity being read AGAIN, later,
#     off a nameplate token that is recycled -- so a scan that threw its own
#     reading away hands the aura on and the next scan asks who holds that token
#     now. The debt, the chat line, the amber prompt and the /say the click
#     speaks then all name a bystander. It also puts a name on an aura that had
#     none when it was seen, which is the same lie from the other end.
mutate("Core.lua",
       "\t-- A different aura under the same number is a different sighting.\n"
       "\tif seen and seen.key == key then return end\n",
       "",
       "the caster read at the announcement",
       expect="the favour was filed against whoever was holding the token",
       script="runscenarios.py")

# 49. the corroborating reading waited for rather than asked for. Nothing looks
#     wrong: the baseline still settles, still takes two readings that agree,
#     and every scenario that drives UNIT_AURA by hand passes. In game it means
#     the second reading is whatever the client sends next, which on a character
#     who zones in and stands still is minutes -- and everything landing in that
#     window is filed as something they were already carrying.
mutate("Core.lua",
       "\t\telse\n"
       "\t\t\t-- And the reading that has to agree is asked for on the clock.",
       "\t\telseif false then\n"
       "\t\t\t-- And the reading that has to agree is asked for on the clock.",
       "a baseline settling when the client says so",
       expect="the baseline never settled without an event",
       script="runscenarios.py")

# 50. an aura identified by its instance id alone. Ids are recycled here, and
#     the prune leaves an expired entry in the baseline for one more reading, so
#     there is a whole scan in which a different aura arrives under a dead
#     number and is matched against the corpse.
mutate("Core.lua",
       "\tif known == nil or known ~= key then return true end\n",
       "\tif known == nil then return true end\n",
       "an aura identified by its number alone",
       expect="a different spell arriving under a recycled number",
       script="runscenarios.py")

# 51. and the half of that the spell id cannot reach: the ordinary re-buff,
#     arriving under its own predecessor's number with its own spell on it. The
#     number matches, the spell matches, and the only thing left that separates
#     "it ran out and was cast again" from "the client withheld it for one
#     reading" is that a replacement ends later than what it replaced.
mutate("Core.lua",
       "\treturn (was ~= nil and expires ~= nil and expires > was) or false\n",
       "\treturn false\n",
       "a re-buff told apart by nothing",
       expect="a re-buff arriving under its own predecessor's number",
       script="runscenarios.py")

# 52. and the bound on the other side of it. Asking for the next reading from
#     inside the last one is a chain, and a client that never answers is a
#     chain that never ends -- a forty-slot aura walk every fifth of a second
#     for the rest of the session, for a baseline that is not going to settle.
mutate("Core.lua",
       "\tif settlePending or settleTries >= SETTLE_TRIES then return end\n",
       "\tif settlePending then return end\n",
       "a settling chain with no end to it",
       expect="a client that never settles is still being scanned on a timer",
       script="runscenarios.py")

# 53. the rule this file's whole click machinery works to -- a record is never
#     discarded silently -- broken at the abandon. The slot is cleared above
#     the staleness test, so the sweep it defers to can never see the record
#     again, and the twelve-second cooldown and the rotation pointer that press
#     wrote both stand over a cast that never happened.
mutate("Core.lua",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return
	end
	ns.pendingClick = nil
	SayStillOwed(pending.name, "another press arrived before the game answered that one",""",
       """	ns.pendingClick = nil
	if GetTime() - pending.at > SETTLE_SECONDS then return end
	SayStillOwed(pending.name, "another press arrived before the game answered that one",""",
       "a dead record dropped by the abandon",
       expect="a second press: the twelve-second cooldown stood over a press that cast nothing",
       script="runscenarios.py")

# 54. and by the other two doors. A cast event or an error arriving after the
#     window is not about that press, but the press is still owed its undoing,
#     and clearing the slot is what guarantees nobody ever does it.
mutate("Core.lua",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending,
			"the game never answered that press, and this cast came too late to be its answer")
		return
	end""",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ns.pendingClick = nil
		return
	end""",
       "a dead record dropped by the settle",
       expect="a later cast event: the twelve-second cooldown stood over a press that cast nothing",
       script="runscenarios.py")

# 55. the confirmed tick on the weakest evidence in the file. A selfCast macro
#     has no /target by construction, no recipient in the cast event, and
#     nothing anywhere tying the spell to the person named -- strictly less
#     than the targeted branch, which deliberately stops at "sent".
mutate("Core.lua",
       '\t\t\tinferred = "selfcast"\n',
       "\t\t\tinferred = nil\n",
       "a selfCast buff claimed as confirmed",
       expect="the panel confirmed a buff that nothing ties to the person named",
       script="runscenarios.py")

# 56. the server's answer arriving after the client reported sending. The
#     settle has let the record go by then, so the failure handler returned on
#     its first line: no red flash, no chat line, and a tick left standing over
#     a cast that was thrown away.
mutate("Core.lua",
       """	if not ns.pendingClick then
		local late = UnsettleLateRefusal(castGUID)
		if late then ShowOutcome("failed", late, "the game refused the cast") end
	end
""",
       "",
       "a refusal arriving after the send",
       expect="a cast the server refused stayed filed as a favour repaid",
       script="runscenarios.py")

# 57. and the check that keeps it honest. UNIT_SPELLCAST_FAILED names the cast
#     it refuses, so it is the only one that can tell our own cast being refused
#     from anything else on the bar failing in the same second -- and without
#     that comparison a confirmed buff is undone by somebody else's miss. (This
#     was a spell-id check until only the guid was allowed to match; the fault
#     is the same, re-anchored.)
mutate("Core.lua",
       "\t\tif record.castGUID == castGUID then return i end",
       "\t\treturn i",
       "a refusal credited to the wrong spell",
       expect="an unrelated spell failing undid a confirmed cast",
       script="runscenarios.py")

# 57b. the same check read the permissive way round. Everywhere else a
#      withheld value must settle, because one withheld number must not make a
#      favour permanent -- but this is the one direction where no evidence has
#      to mean no action, and borrowing that leniency reopens a repaid debt on
#      every failure the client will not name. Two withheld guids compare equal,
#      which is exactly that leniency in the form it takes now.
mutate("Core.lua",
       "\tif castGUID == nil then return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "\tfor i, record in ipairs(settledRecent) do",
       "an unnamed failure treated as ours",
       expect="a failure the client would not put a spell id on undid a confirmed cast",
       script="runscenarios.py")

# UI_ERROR_MESSAGE used to drive UnsettleLateRefusal as well, and that is what
# made the permissive check above catastrophic rather than merely wrong: an
# event with no spell id on it, handed to a test that reads a missing id as
# ours. It is unwired now, and there is deliberately no mutation for putting it
# back, because with 57b's check in place it cannot do any harm -- it is dead
# code, not a live fault, and a mutation that cannot go red would report CAUGHT
# for the rest of time. The scenario still presses on the symptom itself: an
# error inside the window leaves a confirmed settle alone.

# 57e. a debt raised, written to disk and announced with the addon switched
#      off. NoteFavour refuses to do exactly that at the other end of the same
#      write, calling it the same lie told louder.
mutate("Core.lua",
       """	local db = addon.db and addon.db.profile
	if not db or not db.enabled then return nil end
""",
       "",
       "a switched-off addon raising a debt",
       expect="a switched-off addon raised a debt it has no way of repaying",
       script="runscenarios.py")

# 58. the click outcome painted into the name line of a panel frozen for a
#     fight, and never painted out of it. The sub-line underneath was rewritten
#     on every pass and the name line was not, so a past-tense headline about
#     one person became the title over a macro aimed at another.
mutate("Prompt.lua",
       "\t\t\t\tnameText:SetText(self:RenderPrimary(current, 0))\n",
       "",
       "a confirmation left as the panel's title",
       expect="became the panel's title for the rest of the fight",
       script="runscenarios.py")

# 59. and the other half of the same branch: Show on a secure frame, which
#     Blizzard refuses for the length of the fight. A refused Hide is invisible;
#     a refused Show is the confirmation not appearing, which is the feature.
mutate("Prompt.lua",
       """		if self:OutcomeLive() and not p.hideInCombat then
			self:PaintOutcome()""",
       """		if self:OutcomeLive() and not p.hideInCombat then
			button:Show()
			self:PaintOutcome()""",
       "a protected Show inside the combat branch",
       expect="on the secure button in combat",
       script="runscenarios.py")

# 60. the combat dim released at the bottom of Refresh, which preview returns
#     above. Written as the blind spot rather than as a deletion: every other
#     path still heals, so only the check that is about preview can catch it.
mutate("Prompt.lua",
       "\tif not InCombatLockdown() then self:SetCombatHold(false) end",
       "\tif not InCombatLockdown() and not testMode then self:SetCombatHold(false) end",
       "a preview left holding the dim of a fight",
       expect="the fight ended and the preview stayed dimmed",
       script="runscenarios.py")

# 61. the grace-window entry built without the field that says whether anybody
#     chose not to look. Missing reads as false, and false is the line that
#     blames the user's own options for a reading no unit token existed to take.
mutate("Core.lua",
       '\t\t\t\t\t\tchecked = (f.whenBuffed or "skip") ~= "always",\n',
       "",
       "a tokenless favour blamed on the options",
       expect="blamed the user's options",
       script="runscenarios.py")

# 62. the dropdown naming a thing the addon does not do. This is the whole of
#     the old bug: the entry existed, the addon drew no border of any kind, and
#     nothing anywhere could tell the difference.
mutate("Options.lua",
       '\t\t\t\t\t\t\tframed = "Framed -- flat panel, thin border",',
       '\t\t\t\t\t\t\tblizzard = "Blizzard -- default UI border",',
       "a look the addon draws nothing for",
       expect="the dropdown still offers a name the addon draws nothing for",
       script="runscenarios.py")

# 63. and the border itself, which is what makes that entry true.
mutate("Prompt.lua",
       "\t\tedge:SetShown(framed)",
       "\t\tedge:SetShown(false)",
       "a border the look promises and never draws",
       expect="of its four edges",
       script="runscenarios.py")

# 64. the profile carried across. Without it the repair below reads the stored
#     name as nonsense and hands back the default look, which is a silent
#     change to something the user chose.
mutate("Core.lua",
       '\tif p.style == "blizzard" then p.style = "framed" end\n',
       "",
       "a stored look quietly reset instead of migrated",
       expect="instead of the look it asked for",
       script="runscenarios.py")

# 65. the second return of the aura read, dropped on the floor by the exclusive
#     branch -- so the refresh mode was switched on, described in the options,
#     and dead for the one class it is safest on.
mutate("Core.lua",
       """				-- class it is safest on -- see the top-up below.
				local held, remaining, mine = has(buff)""",
       """				-- class it is safest on -- see the top-up below.
				local held, _, mine = has(buff)""",
       "a top-up with the timer thrown away",
       expect="was offered no top-up at all",
       script="runscenarios.py")

# 66. and the mode itself, which that branch never consulted. Offering a top-up
#     to everybody covered is the same branch failing in the other direction:
#     a setting that says "leave them alone" ignored.
mutate("Core.lua",
       '\t\t\t\t\tif opts.whenBuffed == "refresh" and remaining\n',
       "\t\t\t\t\tif remaining\n",
       "a top-up offered with the mode switched off",
       expect="the top-up mode is switched off",
       script="runscenarios.py")

# 67. the threshold. "When it is running out" is the whole of the offer, and
#     without a live comparison every covered person is on the prompt for ever.
mutate("Core.lua",
       "\t\t\t\t\t\tand remaining <= (opts.refreshUnder or 5) * 60 then",
       "\t\t\t\t\t\tand remaining <= (opts.refreshUnder or 5) * 6000 then",
       "a top-up for a blessing with an hour left",
       expect="a blessing with an hour left was answered",
       script="runscenarios.py")

# 68. the other side of the combat branch's repaint, which was never written at
#     all. 58 above covers the guarded half; this is the `else` that did not
#     exist, so a fight that began with nobody on the panel kept the click's
#     green headline for its whole length over a button holding no macro.
mutate("Prompt.lua",
       '\t\t\t\tself:PaintHeldInert("held")\n',
       "",
       "a held panel that names nobody at all",
       expect="stops quoting the last click",
       script="runscenarios.py")

# 69. and the half that decides which of the two held states it is. An emptied
#     button and one the fight froze still armed read identically without it,
#     and only one of them casts on a press.
mutate("Prompt.lua",
       '\tlocal frozen = button:GetAttribute("macrotext1")',
       "\tlocal frozen = true",
       "a disarmed panel warning about a cast",
       expect="does not say the button is empty",
       script="runscenarios.py")

# 70. Hide called straight from a branch that returns above the combat branch,
#     which is where all four of these sat: refused, silently, on every tick of
#     every fight, with the branch walking away believing the panel had gone.
mutate("Prompt.lua",
       '\t\tif not SetPanelShown(false) then self:PaintHeldInert("switched off") end',
       "\t\tbutton:Hide()",
       "a switched-off addon hiding in combat",
       expect="/manners off in combat called",
       script="runscenarios.py")

# 71. the same call in the branch that has nothing to cast, which can become
#     true mid-fight the moment the client answers SPELLS_CHANGED.
mutate("Prompt.lua",
       """		if not SetPanelShown(false) then
			self:PaintHeldInert("nothing this character can cast")
		end""",
       "\t\tbutton:Hide()",
       "a client with nothing to cast hiding in combat",
       expect="a client with nothing to cast in combat called",
       script="runscenarios.py")

# 72. and the preview's Show, which is the one call that would make a mock-up
#     appear over a panel the fight found hidden -- so a refusal here is the
#     whole feature not happening rather than an invisible no-op.
mutate("Prompt.lua",
       "\t\tif not button:IsShown() and SetPanelShown(true) then",
       "\t\tif not button:IsShown() and (button:Show() or true) then",
       "a preview calling Show during a fight",
       expect="the fight found hidden called",
       script="runscenarios.py")

# 73. the unlocked branch, caught from the other direction. Guarding the Show
#     and then painting the same line anyway leaves the panel telling the user
#     to drag a frame OnDragStart refuses for exactly as long as Show does.
mutate("Prompt.lua",
       "\t\tif SetPanelShown(true) then",
       "\t\tif true then",
       "an unlocked prompt inviting a drag in combat",
       expect="told the user to drag it during a fight",
       script="runscenarios.py")

# 74. the Hide that lived inside the combat branch itself. It only ever ran in
#     combat, so it was refused every single time it was made -- deleted rather
#     than guarded, because a guard on it would be just as dead.
mutate("Prompt.lua",
       "\t\tlocal debt = current and current.name and ns.owed[current.name]",
       """		if p.hideInCombat or not current then button:Hide() end
		local debt = current and current.name and ns.owed[current.name]""",
       "the combat branch's own refused Hide",
       expect="repainting the held panel called",
       script="runscenarios.py")

# 75. the label that promised a per-player wait over a click that blocks one
#     spell. The wording is the bug here, so the wording is what goes back.
mutate("Options.lua",
       '''desc = "After you click, how long before that spell is offered to that"
							.. " player again. Covers casts that failed out of sight.\\n\\n"''',
       '''desc = "After you click, how long before the same player can come back up."
							.. " Covers casts that failed out of sight.\\n\\n"''',
       "a per-spell wait sold as a per-player one",
       expect="the same player can come back up",
       script="runscenarios.py")

# 76. and the same disagreement arriving from the other side: the label left
#     alone and the click made to block the person, which is what the old
#     wording described and what would stop the buff walk dead.
mutate("Prompt.lua",
       "\t\t\tns.MarkAttempted(current.name, current.buff.key)",
       "\t\t\tns.BlockPerson(current.name)",
       "a click blocking the person the label denies",
       expect="blocks the whole person while the page says",
       script="runscenarios.py")

# 77. the one place the number really is per person, taken back off the page.
mutate("Options.lua",
       '.. " down your buffs works at all. Right-click the prompt to skip"',
       '.. " down your buffs works at all. There is another way to skip"',
       "the per-person half left unmentioned",
       expect="is nowhere on the page",
       script="runscenarios.py")

# 78. AceConfigRegistry called straight from a control. It is fetched with the
#     silent flag precisely because it may be absent, and the icon slider's
#     setter was once the one reader that did not check -- so the absence it is
#     fetched for threw, from inside a set, with somebody's finger on the
#     slider. That setter no longer asks for a repaint at all -- the dialog
#     redraws itself when the slider is let go -- so the check now sits on the
#     one control that still repaints the page from a press: the bug report.
mutate("Options.lua",
       "\t\t\t\t\t\t\treportOpen = not reportOpen\n\t\t\t\t\t\t\tns.RefreshOptionsDisplay()",
       "\t\t\t\t\t\t\treportOpen = not reportOpen\n\t\t\t\t\t\t\tAceConfigRegistry:NotifyChange(ADDON)",
       "a control calling a library that may be absent",
       expect="opening the bug-report box threw",
       script="runscenarios.py")

# 79. the clamp the icon slider never ran. The bound cannot live on the control
#     -- AceConfig rejects the whole table for a function where it wants a
#     number -- so the setter is the only place left to apply it, and it did
#     not, under a notice claiming the icon was being held.
mutate("Options.lua",
       # Anchored on the comment that follows it: the height slider's setter is
       # the same three lines, sits earlier in the file, and would otherwise be
       # the one this replaced -- which is a mutation of a different check.
       "\t\t\t\t\t\t\tns.ClampSettings()\n\t\t\t\t\t\t\trestyle()\n\t\t\t\t\t\t\t-- Repainted only",
       "\t\t\t\t\t\t\t-- Repainted only",
       "an icon slider that outgrows its panel",
       expect="dragging the icon slider left an icon taller",
       script="runscenarios.py")

# 80. the description that named three reason colours out of four, leaving out
#     the one most people see most often.
mutate("Options.lua",
       'desc = "Pale blue for somebody you targeted yourself, amber when returning a"',
       'desc = "Amber when returning a"',
       "a reason colour the page never names",
       expect="reason colours and the description names",
       script="runscenarios.py")

# 81. and the setting that silently takes the ring away. Rounding the icon puts
#     a mask where the ring was, so "Ring around the icon" -- the default --
#     ends up over a prompt with no reason colour anywhere on it.
mutate("Options.lua",
       'local ring = (mode == "icon" or mode == "both") and p.showIcon and not p.roundIcon',
       'local ring = (mode == "icon" or mode == "both") and p.showIcon',
       "a ring the page believes in after it is gone",
       expect="rounded icon leaves the reason colour with nowhere to go",
       script="runscenarios.py")

# 82. the targeting switch offered to a class whose macro never takes a target.
mutate("Options.lua",
       "\t\t\t\t\t\thidden = NeverTargets,\n\t\t\t\t\t\tget = fGetMacro,",
       "\t\t\t\t\t\tget = fGetMacro,",
       "handing back a target that is never taken",
       expect="hand back a target the macro never takes",
       script="runscenarios.py")

# 83. "Hide in combat" over a panel that cannot be hidden. The call that read
#     it was protected and refused every time it ran, and it is gone.
mutate("Options.lua",
       'name = "Stay quiet in combat",',
       'name = "Hide in combat",',
       "a switch named for something it cannot do",
       expect="is still called",
       script="runscenarios.py")

# 84. and the thing it does do, taken away -- which would leave a switch that
#     is now genuinely wired to nothing at all.
mutate("Prompt.lua",
       "\t\tif self:OutcomeLive() and not p.hideInCombat then",
       "\t\tif self:OutcomeLive() then",
       "a combat switch wired to nothing",
       expect="still flashed the click's outcome",
       script="runscenarios.py")

# 85. the source list that named three of the four unit tokens the scan walks.
mutate("Options.lua",
       '.. "Seen through nameplates, your target, your focus and your mouseover.",',
       '.. "Seen through nameplates, your target and your mouseover.",',
       "a way of reaching somebody left off the page",
       expect="does not mention it",
       script="runscenarios.py")

# 86. and the chat switch described as one line when it prints seven kinds --
#     the useful ones being what each click turned into.
mutate("Options.lua",
       '''desc = "A line when somebody buffs you, and a line for what each click turned"
							.. " into -- cast, refused, skipped, or still owed.\\n\\n"''',
       '''desc = "A line when somebody buffs you.\\n\\n"''',
       "a chat switch narrower on the page than in the code",
       expect="still describes it as a line for when somebody buffs you",
       script="runscenarios.py")

# 87. the grace window described as running from the moment we lose sight of
#     somebody, which is a thing nothing in the addon can notice. It runs from
#     their buff -- the one instant they were provably in range.
mutate("Options.lua",
       '''desc = "How long after somebody buffs you that counts as proof they were in"
					.. " range. It runs from their buff, not from the moment they walk off:"
					.. " nothing here can see them go.",''',
       'desc = "How long a favour stays offerable once we can no longer see them.",',
       "a window timed from an event nothing sees",
       expect="the page does not say so",
       script="runscenarios.py")

# The settle record held one slot and a timestamp kept outside it, so a record
# a refusal had already consumed went on suppressing the next press for the
# rest of the window -- and two presses inside it, which is the buff walk
# working as designed, threw both records away.
mutate("Core.lua",
       """local function RememberSettled(record)
\tPruneSettled(record.at)
\tsettledRecent[#settledRecent + 1] = record
end""",
       """local lastSettleAt
local function RememberSettled(record)
\tlocal previous = lastSettleAt
\tlastSettleAt = record.at
\twipe(settledRecent)
\tif previous and record.at - previous <= SETTLE_SECONDS then return end
\tsettledRecent[1] = record
end""",
       "a settle record that outlives the refusal that answered it",
       expect="a refusal is matched to the press it answers",
       script="runscenarios.py")

# Both cast events carry a guid naming the cast, and both handlers discarded it
# into an underscore -- which is the identity the timestamp above was trying to
# reconstruct from the clock. Since the guid became the only thing allowed to
# match, ignoring it means no refusal is ever matched at all.
mutate("Core.lua",
       "\tif castGUID == nil then return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "\tdo return nil end\n\tfor i, record in ipairs(settledRecent) do",
       "the cast guid ignored, the way both handlers used to",
       expect="a refusal is matched to the press it answers",
       script="runscenarios.py")

# --- which client this is ---------------------------------------------
#
# Every mutation below is a bug that produces an addon which looks installed and
# does nothing, or one that quietly hands a client the wrong answer about itself.
# Neither has a symptom anybody can describe, which is why they are here.

# The band trap: a matcher that works on "five digits beginning with a 1" puts
# Forever in the vanilla band, and vanilla content is exactly what Forever runs,
# so it half-works and nobody ever files anything.
mutate("Flavour.lua",
       '\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       '\t{ flavour = "vanilla", family = "classic", min = 11000, max = 19999 },',
       "the band trap (Forever read as vanilla)",
       expect="interface 16001 is camelot",
       script="runscenarios.py")

# nil == nil. Drop the type check and every project-id comparison passes at once
# on a client that has none of the constants, so the first entry in the list
# wins -- a modern client told it is Mists, and that the combat log is there.
mutate("Flavour.lua",
       '\tif type(id) ~= "number" or type(want) ~= "number" then return false end',
       "\tif false then return false end",
       "project id compared without checking both sides are numbers",
       expect="a client with no project constants at all",
       script="runscenarios.py")

# Flavour.lua is the first file the toc names. Anything it throws takes the whole
# addon down before there is a slash command left to ask what happened.
mutate("Flavour.lua",
       "local ok, decided = pcall(Decide)",
       "local ok, decided = true, Decide()",
       "flavour detection not wrapped (no GetBuildInfo kills the addon)",
       expect="a client with no GetBuildInfo",
       script="runscenarios.py")

# An unrecognised number rejected rather than classified. The client still has
# somebody sitting in front of it, and the number is the one thing their bug
# report needs to carry.
mutate("Flavour.lua",
       "\tlocal band = out.interface and BandFor(out.interface)",
       '\tlocal band = assert(out.interface and BandFor(out.interface), "unknown client")',
       "an unknown interface number treated as a failure",
       expect="an interface number with no band",
       script="runscenarios.py")

# --- what follows from it ---------------------------------------------

# The combat log answered by assertion instead of by trying it. The probe's
# whole value is that it can be wrong out loud on a client nobody here can run.
mutate("Core.lua",
       '\tlocal ok = pcall(probeFrame.RegisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")',
       "\tlocal ok = true",
       "the combat log probe that never actually registers",
       # Caught by an unrecognised client, not by Forever. Forever is NAMED as
       # modern, so the probe is deliberately not run there -- asking is itself
       # the forbidden action. A client nobody can name is the only place the
       # probe decides anything, which is exactly where it has to be honest.
       expect="a client with no GetBuildInfo",
       script="runscenarios.py")

# Conditional targeting turned on for Camelot -- the one client whose behaviour
# is not allowed to move, and the only one this addon is verified on.
mutate("Core.lua",
       '\tcaps.conditionalTargeting = flavour.flavour ~= "camelot"',
       "\tcaps.conditionalTargeting = true",
       "conditional targeting assumed on Camelot",
       expect="capabilities on Forever",
       script="runscenarios.py")

# UnitName's second return read as a realm on the one client where it is a
# surname, which turns "Mort Defrette" into "Mort-Defrette" -- a name no
# targeting call will ever find, and a key no debt on disk is filed under.
mutate("Core.lua",
       '\treturn (ns.Flavour and ns.Flavour.flavour) == "camelot"',
       "\treturn false",
       "a surname read as a realm on Camelot",
       expect="capabilities on Forever",
       script="runscenarios.py")

# And the mirror: a realm read as a surname, which is what the code did on every
# client until this round. "Mort Ravencrest" resolves to nobody, so the macro
# targets whoever you already had and buffs them instead.
mutate("Core.lua",
       '\t\tfull = name .. (SurnameClient() and " " or "-") .. second',
       '\t\tfull = name .. " " .. second',
       "a realm joined to a name with a space",
       expect="UnitName's second return on vanilla",
       script="runscenarios.py")

# The realm left on the targeting line. /target is a name search over drawn-in
# units and the realm is not part of what it searches, so this is a macro that
# finds nobody -- and finding nobody means the cast lands on whoever you already
# had targeted.
mutate("Core.lua",
       "\tif SurnameClient() then return name end\n\treturn ShortName(name)",
       "\treturn name",
       "the realm left on the targeting line",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")

# Identity and spelling collapsed back into one string: the queue stops carrying
# the spelling and the builder falls back to the key, which is the shape this
# whole split exists to prevent.
mutate("Core.lua",
       "\t\t\ttargetName = ns.TargetName(full),\n\t\t\tunit = unit,",
       "\t\t\tunit = unit,",
       "the queue stops carrying the spelling to aim at",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")

# The settle path re-deriving the spellings it will accept instead of being told
# what the macro aimed at. Off Camelot the game names the person by the spelling
# the macro used, which is not the key -- so every cross-realm favour is reported
# as having gone to a stranger and never settles.
mutate("Core.lua",
       "\telseif landedOn and landedOn ~= pending.aimedAt\n\t\tand landedOn ~= pending.name",
       "\telseif landedOn and landedOn ~= pending.name",
       "the settle path guesses at what the macro aimed at",
       expect="the settle path is told what the macro aimed at",
       script="runscenarios.py")

# The record a strategy hands the settle path, filled in wrong. A self-cast
# shout has no recipient in the cast event and no targeting line to tie it to
# anybody, so calling it a targeted cast makes the settle look for a name that
# was never in the macro -- and a warrior's only way of repaying anybody stops
# working, which is the exact bug the record was introduced to end.
mutate("Prompt.lua",
       "\t\t{ targeted = false, selfCast = true, aimedAt = nil }",
       "\t\t{ targeted = true, selfCast = false, aimedAt = nil }",
       "a self-cast macro recorded as a targeted one",
       expect="a warrior can repay a favour",
       script="runscenarios.py")

# The console's two name tokens collapsed back into one. It is the tool for
# working out what resolves on a client nobody here can start, so a token that
# sometimes means the key and sometimes the spelling makes every experiment run
# on it ambiguous -- and the answer would be reported back as fact.
mutate("Core.lua",
       '\ttext = ns.Swap(text, "{aim}", (entry and (entry.targetName or entry.name)) or "target")',
       '\ttext = ns.Swap(text, "{aim}", (entry and entry.name) or "target")',
       "the console's {aim} token handing back the key",
       expect="the key keeps the realm and the macro drops it",
       script="runscenarios.py")
# There is deliberately no second mutation of TargetCommand here. It used to
# carry one for "probed for and never written", which was the opposite fault
# from the one above -- but the probe no longer reaches the macro at all, by
# decision, so both directions collapse into the single check above.


# And the other way: a command written into the macro on a client that does not
# have it. An unknown slash command is not an error the user sees -- the line is
# simply dropped, the cast goes to whoever was already targeted, and the addon
# says a favour was returned.
mutate("Prompt.lua",
       '\treturn "/target"\nend',
       '\treturn "/targetexact"\nend',
       "/targetexact written after it was deliberately withdrawn",
       expect="a client without /targetexact builds /target",
       script="runscenarios.py")

# Secret restrictions inferred from the namespace existing, which is the wrong
# question: C_Secrets is present on clients that are withholding nothing.
mutate("Core.lua",
       "\tcaps.secretRestrictions = safecall(C_Secrets and C_Secrets.HasSecretRestrictions)",
       '\tcaps.secretRestrictions = type(C_Secrets) == "table"',
       "secret restrictions inferred from C_Secrets being there",
       expect="C_Secrets present and nothing actually restricted",
       script="runscenarios.py")

# A command believed in rather than probed. /target matches a name prefix, so
# this is how "/target Mort" ends up buffing Mortimer.
mutate("Core.lua",
       """\tcaps.targetExact = (type(secureCommands) == "table"
\t\t\tand type(secureCommands.TARGET_EXACT) == "function")
\t\tor type(_G.SLASH_TARGET_EXACT1) == "string\"""",
       "\tcaps.targetExact = true",
       "/targetexact assumed rather than probed",
       expect="a client without /targetexact",
       script="runscenarios.py")

# The early return back above the lines that name the build, which is where it
# was: a class with nothing to cast filed a report that never said which client
# it came from.
mutate("Core.lua",
       '\t\tself:Print("client: |cffffffff"',
       """\t\tif not caps.hasClassBuffs then return end
\t\tself:Print("client: |cffffffff\"""",
       "debug returns early before naming the client",
       expect="debug names the client for a class with nothing to cast",
       script="runscenarios.py")

# The file list trap from the other side: Flavour.lua missing from a toc leaves
# ns.FlavourSummary nil, and an unguarded call to it takes down the one command
# that could have said which file never loaded.
mutate("Core.lua",
       """\t\t\t.. (ns.FlavourSummary and ns.FlavourSummary()
\t\t\t\tor "|cffff4040Flavour.lua did not load -- check the toc's file list|r")""",
       "\t\t\t.. ns.FlavourSummary()",
       "debug throws when Flavour.lua never loaded",
       expect="a toc that lost Flavour.lua from its file list",
       script="runscenarios.py")

# No buff table, and nothing to catch it. ipairs over nil throws during load,
# and a file that throws during load leaves no addon at all -- which from the
# user's side is indistinguishable from never having installed it.
mutate("Buffs.lua",
       '\tif type(ns.BUFFS) ~= "table" then',
       "\tif false then",
       "a missing buff table left to throw during load",
       expect="no buff table for this client",
       script="runscenarios.py")

# --- which spells this client has ------------------------------------
#
# Every mutation below hands a client somebody else's spell list. None of them
# throws, none of them looks wrong on screen, and each one ends as a class that
# is quietly never offered anything on a client nobody here can start.

# A flavour pointed at the wrong set. Two of them, in both directions, because
# the map is the whole of the mechanism and one line in it is one client.
#
# Camelot's own row is deliberately not mutated here: every scenario in the file
# but a handful is a Forever scenario, so changing that line takes the suite down
# outright rather than failing one named check, and there is nothing to attribute
# it to. tests/baseline.py is what guards that row -- it prints what Forever
# decides for every class, and it is run before and after every change.
mutate("Buffs.lua",
       "\tmists = MISTS_SET,",
       "\tmists = VANILLA_SET,",
       "a flavour handed the previous expansion's spells",
       expect="mists gets the mists spells",
       script="runscenarios.py")

mutate("Buffs.lua",
       "\tvanilla = VANILLA_SET,",
       "\tvanilla = MAINLINE_SET,",
       "a flavour handed retail's five spells",
       expect="vanilla gets the vanilla spells",
       script="runscenarios.py")

# A class that exists on one client and not another. Monks were added to this
# file for Mists and have never been in it before, so dropping them is the shape
# the next flavour's mistake will take.
mutate("Buffs.lua",
       "\tMONK = {",
       "\tNOTAMONK = {",
       "a class that only one flavour has, missing from it",
       expect="mists gets the mists spells",
       script="runscenarios.py")

# The contradiction: a class with a spell list, also listed as having nothing.
# Which of the two the user is shown depends on which screen they open, and the
# shaman is exactly the class that moved -- totems on vanilla, Skyfury on retail.
mutate("Buffs.lua",
       "\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "\t\tSHAMAN = true,\n\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "a class both given spells and listed as having none",
       expect="mainline gets the mainline spells",
       script="runscenarios.py")

# The other half of it: a class that really does have nothing, left off the list
# that lets the options page say so. The page then falls back to "could not work
# out what you can cast", which sends somebody looking for a broken spell probe.
mutate("Buffs.lua",
       "\t\tPALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3",
       "",
       "a class with nothing left to say it has nothing",
       expect="a retail paladin is told so plainly",
       script="runscenarios.py")

# An unrecognised client left with no spells at all. Flavour.lua refuses to
# reject a client it cannot name, and this is the same promise one file along.
mutate("Buffs.lua",
       "local BY_FAMILY = { classic = VANILLA_SET, modern = MAINLINE_SET }",
       "local BY_FAMILY = {}",
       "an unrecognised client given no spells at all",
       expect="an interface number with no band",
       script="runscenarios.py")

# Aura ids that are not the cast id, dropped. Blessing of the Bronze is cast as
# one id and lands as thirteen others, so this is a buff that can never be seen
# on anybody: the person just blessed reads as missing it.
mutate("Buffs.lua",
       """\t\t\tfor _, id in ipairs(buff.group or {}) do
\t\t\t\tbuff.auraIds[#buff.auraIds + 1] = id
\t\t\tend""",
       "",
       "the aura ids that are not the cast id, dropped",
       expect="one cast that lands as thirteen different auras",
       script="runscenarios.py")

# A spell that is offerable but must never be automatic, offered automatically.
# Unending Breath handed to a stranger in a city is how an addon gets
# uninstalled, and the walk finds it the moment Dark Intent is not available.
mutate("Core.lua",
       "\t\t\tand (not buff.neverAuto or pinned == buff.key) then",
       "\t\t\tand true then",
       "Automatic walking onto a spell marked never-automatic",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The same rule on the other path into it -- the one that answers when the walk
# has nothing left.
mutate("Core.lua",
       """\t\tif ns.IsBuffKnown(buff) and not buff.neverAuto
\t\t\tand not (skip and skip[buff.key]) then""",
       "\t\tif ns.IsBuffKnown(buff) then",
       "the never-automatic rule missing from the fallback pick",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The page then blames the switches -- "every spell below is switched off" --
# for a spell Automatic is holding back on purpose, which sends somebody to a
# control that is already set the way they want it.
mutate("Options.lua",
       "\t\t\tif buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then",
       "\t\t\tif false then",
       "the page blaming the switches for a never-automatic spell",
       expect="Automatic never hands over Unending Breath",
       script="runscenarios.py")

# The failure with no symptom: an id this client does not have. The probe
# reports "not learned", which is what an unlearned spell reports, so the buff
# is never offered and nothing anywhere says why.
mutate("Core.lua",
       "\t\tif not SpellNameFor(id) then",
       "\t\tif false then",
       "a spell id the client does not have, absorbed in silence",
       expect="a spell id this client has never heard of",
       script="runscenarios.py")

# And the same finding kept off the options page, where far more people will see
# it than will ever type a slash command.
mutate("Options.lua",
       """\t\t\t\t\t\t\t\tif info and info.unresolved and #info.unresolved > 0 then
\t\t\t\t\t\t\t\t\tlines[#lines + 1] = ("|cffff4040    this client has never heard of\"""",
       """\t\t\t\t\t\t\t\tif false then
\t\t\t\t\t\t\t\t\tlines[#lines + 1] = ("|cffff4040    this client has never heard of\"""",
       "wrong spell data reported to the console and nowhere else",
       expect="a spell id this client has never heard of",
       script="runscenarios.py")

# ---------------------------------------------------------------- combat log
# The log is an additional favour source on the three classic flavours, and a
# forbidden registration on the other two. Every mutation below is a way that
# has already gone wrong somewhere in this addon: an event registered on a
# client that does not have it, a capability believed rather than confirmed, a
# second source that files what the first one already filed, and a filter that
# lets the whole log through.

# Asked for everywhere. On Forever and on retail this registration is refused,
# and a refusal inside OnEnable is the failure that once stopped the scanner.
mutate("Core.lua",
       """\tif caps.combatLog then
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()""",
       """\tif true then
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()""",
       "the combat log registered on every client",
       expect="the combat log on camelot",
       script="runscenarios.py")

# The flag set for having tried rather than for having succeeded. A client that
# refuses then has one source and an addon that believes it has two.
mutate("Core.lua",
       """\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
\t\t\tself:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
\t\t\tcombatLogArmed = true
\t\t\tns.logScan.armed = true
\t\tend)""",
       """\t\tcombatLogArmed = true
\t\tns.logScan.armed = true
\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
\t\t\tself:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
\t\tend)""",
       "the log armed whether or not it registered",
       expect="a classic client that refuses the combat log",
       script="runscenarios.py")

# No agreement between the two sources at all: one cast, two announcements.
mutate("Core.lua",
       "\tif not combatLogArmed then return true end",
       "\tif true then return true end",
       "two sources announcing one landing",
       expect="one landing seen twice",
       script="runscenarios.py")

# The mark left standing instead of consumed, which turns the agreement into a
# suppression window and swallows the next real favour inside it.
mutate("Core.lua",
       """\tif claimed and now - claimed <= NOTE_MEMORY then
\t\tnotedFavours[key] = nil
\t\treturn false
\tend""",
       """\tif claimed and now - claimed <= NOTE_MEMORY then
\t\treturn false
\tend""",
       "a suppression window instead of a claim",
       expect="the mark was a timer, not a claim",
       script="runscenarios.py")

# The aura scan going round the agreement, which is the same duplicate arriving
# from the other side.
mutate("Core.lua",
       "\t\t\t\t\t\tif ClaimFavour(seen.name, key) then NoteFavour(seen) end",
       "\t\t\t\t\t\tNoteFavour(seen)",
       "the aura scan filing past the claim",
       expect="one landing seen twice, log first",
       script="runscenarios.py")

# A debt filed by hand rather than through NoteFavour -- a prompt that works and
# a user who is never told why, plus nothing written to disk.
mutate("Core.lua",
       "\tNoteFavour({ key = spellId, name = full, guid = sourceGUID, class = plain(class) })",
       """\tns.owed[full] = { expires = GetTime() + 120, at = GetTime(),
\t\tguid = sourceGUID, class = plain(class) }""",
       "the log keeping its own debts",
       expect="a stranger with no nameplate",
       script="runscenarios.py")

# Spelled by a rule of its own rather than by the join both sources share, so
# the same person is filed under two keys and each debt is unpayable by the
# other source.
mutate("Core.lua",
       "\tlocal full = JoinName(plain(name), plain(realm))",
       '\tlocal full = tostring(plain(name)) .. "-" .. tostring(plain(realm))',
       "the log spelling a name its own way",
       expect="a same-realm favour off the log",
       script="runscenarios.py")

# A line the log cannot name a player for, carried on into the machinery.
mutate("Core.lua",
       "\tif not full then return end\n\n\tif not ClaimFavour(full, spellId) then return end",
       "\tif not ClaimFavour(full, spellId) then return end",
       "an unnameable caster carried on into the queue",
       expect="the log ignores an NPC",
       script="runscenarios.py")

# The class taken from the localized return instead of the English one. The two
# are the same word on an English client and the mock is deliberately not, since
# the tokenless fallback branches on the English one.
mutate("Core.lua",
       "\tlocal _, class, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)",
       "\tlocal class, _, _, _, _, name, realm = GetPlayerInfoByGUID(sourceGUID)",
       "the localized class read as the English one",
       expect="a stranger with no nameplate",
       script="runscenarios.py")

# Routed through the aura scan's settled baseline. The corroboration exists
# because a scan can misread its own list; a log line has nothing to doubt, and
# a client that never shows the aura list would otherwise silence both sources.
mutate("Core.lua",
       "\tns.logScan.applied = ns.logScan.applied + 1",
       "\tif not ns.auraScan.primed then return end\n\tns.logScan.applied = ns.logScan.applied + 1",
       "the log waiting on the aura baseline",
       expect="a log line was held back by machinery built for the aura scan",
       script="runscenarios.py")

# The four filters, each dropped on its own. The log carries every event within
# fifty yards, so each of these is the difference between a favour and noise.
mutate("Core.lua",
       '\tif plain(subevent) ~= "SPELL_AURA_APPLIED" then return end',
       "\tif false then return end",
       "every subevent treated as an aura landing",
       expect="the log ignores a subevent that is not an aura landing",
       script="runscenarios.py")

mutate("Core.lua",
       '\tif plain(auraType) ~= "BUFF" then return end',
       "\tif false then return end",
       "a debuff counted as a favour",
       expect="the log ignores a debuff",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif destGUID == nil or destGUID ~= playerGUID then return end",
       "\tif destGUID == nil then return end",
       "somebody else's buff counted as ours",
       expect="the log ignores a buff that landed on somebody else",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif sourceGUID == nil or sourceGUID == playerGUID then return end",
       "\tif sourceGUID == nil then return end",
       "our own buff counted as a favour owed",
       expect="the log ignores our own buff on ourselves",
       script="runscenarios.py")

mutate("Core.lua",
       """\tif db.sources.owedClassBuffsOnly ~= false and not ns.ALL_BUFF_IDS[spellId] then
\t\treturn
\tend""",
       """\tif false then
\t\treturn
\tend""",
       "every incoming aura counted as a class buff",
       expect="the log ignores a heal-over-time",
       script="runscenarios.py")

# ---------------------------------------------------------------- the mock as
# any of the five clients
#
# Three of the mutations below are in tests/mockapi.lua rather than in the addon,
# and that is deliberate. Four of the five clients cannot be started by anybody
# working on this addon, so every claim made about them is really a claim about
# the mock -- and a mock that quietly stops modelling a difference turns the
# scenarios resting on it green for ever. A mock that lies is a fault class here
# in exactly the way a wrong branch in Core.lua is.

mutate("Flavour.lua",
       'local BANDS = {\n\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       'local BANDS = {\n\t{ flavour = "vanilla", family = "classic", min = 11000, max = 16999 },'
       '\n\t{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },',
       "the band trap (Forever read as vanilla)",
       expect="the mock as camelot",
       script="runscenarios.py")

mutate("Flavour.lua",
       '\tif type(id) ~= "number" or type(want) ~= "number" then return false end',
       "\tif false then return false end",
       "nil == nil naming a flavour",
       expect="no project constants on",
       script="runscenarios.py")

mutate("Prompt.lua",
       '\treturn {\n\t\tTargetCommand() .. " " .. who,\n\t\t"/cast " .. spell,\n'
       "\t}, restore,",
       '\treturn {\n\t\t"/cast [@" .. who .. ",help,nodead] " .. spell,\n\t}, false,',
       "the conditional route built after all",
       expect="gets the /target macro",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif SurnameClient() then return name end\n\treturn ShortName(name)",
       "\tif SurnameClient() then return name end\n\treturn name",
       "the realm left on the /target line",
       expect="a player from another realm on",
       script="runscenarios.py")

mutate("Buffs.lua",
       "\t\tDEATHKNIGHT = true,  -- Horn of Winter removed in 11.2.0\n",
       "",
       "a class with nothing, not listed as such",
       expect="a retail deathknight has nothing to offer",
       script="runscenarios.py")

mutate("Core.lua",
       '\tlocal ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")\n'
       "\tif not ok then return nil, true end",
       '\tlocal ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")\n'
       '\tif _G.UnitBuff then pcall(_G.UnitBuff, "player", index) end\n'
       "\tif not ok then return nil, true end",
       "a UnitBuff fallback nobody needs",
       expect="does not use UnitBuff",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif caps.combatLog then\n"
       '\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()',
       "\tif true then\n"
       '\t\tns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()',
       "the combat log registered everywhere",
       expect="the combat log on a whole camelot client",
       script="runscenarios.py")

# The bug the author reported from a city square: everybody the game would let
# him cast on got a card. Reintroduced as the plainest version of itself -- the
# distance is measured and the answer thrown away.
mutate("Core.lua",
       '\t\tif reason == "nearby" and not pointed and ns.NearEnough(unit) == false then',
       "\t\tif false then",
       "a passer-by offered on spell range alone",
       expect="a passer-by in range but not near",
       script="runscenarios.py")

# The same filter applied to the three who carry their own evidence of being
# near. This is the failure worth more than the bug: a deliberate target
# vanishing off the prompt because a coarse distance estimate disagreed.
mutate("Core.lua",
       "and not pointed and ns.NearEnough(unit) == false",
       "and ns.NearEnough(unit) == false",
       "distance applied to a deliberate target",
       expect="who the proximity setting does not apply to",
       script="runscenarios.py")

# Accepting whatever bucket edge the library offers. A two-yard checker standing
# in for "nearby" is the other way to empty the queue, and it reports itself as
# working the whole time.
mutate("Core.lua",
       "if want > PROX_LOOSE_FROM and edge * 2 < want then return nil end",
       "if false then return nil end",
       "a bucket edge far tighter than the setting",
       expect="a checker too tight for the step it would stand in for",
       script="runscenarios.py")

# A signal that resolves and then answers nothing, kept forever. The queue is
# exactly as crowded as it was and the setting says otherwise.
mutate("Core.lua",
       "if silent > PROX_BLIND_LIMIT then",
       "if false then",
       "a signal that never answers, never dropped",
       expect="a signal that resolves and then answers nobody",
       script="runscenarios.py")
# There is deliberately no mutation for the in-combat stand-down.
#
# Two were tried. Removing the stand-down itself changes nothing observable:
# under the mock no proximity signal is built during a fight anyway, so the
# filter measures nobody either way. Removing the line that SAYS so does not
# go red either, because the scenario asserts on who ends up in the queue and
# not on the text of the summary.
#
# The behaviour is still covered -- "nobody is measured in a fight" pins the
# queue -- and a mutation that cannot go red is a check that does not exist.
# Recorded here rather than left as a passing entry implying coverage.


# A named distance a later version stopped implementing, left in a profile. It
# falls through every branch that reads it into "measure nothing", which is the
# noisy queue back with a setting that denies it.
mutate("Core.lua",
       '\toneOf(profile.filters, "proximity", proximities, "near")',
       "",
       "an unrecognised distance left in a profile",
       expect="garbage profile",
       script="runscenarios.py")

# The mock's interact prompt answering yes to everybody, which would make every
# assertion about who is too far away an assertion about nothing.
mutate("tests/mockapi.lua",
       "\treturn Mock.yardsFor(unit) <= limit",
       "\treturn true",
       "the mock calling everybody near",
       expect="a passer-by in range but not near",
       script="runscenarios.py")

# The mock forgetting that only a player from another realm has a second return,
# which would make "Mort-Ravencrest" the ordinary spelling and hide every bug in
# the path nearly every player takes.
mutate("tests/mockapi.lua",
       "\tif Mock.surnames or Mock.crossRealm then return second end\n\treturn nil",
       "\treturn second",
       "the mock giving everybody a realm",
       expect="a same-realm player on",
       script="runscenarios.py")

# The mock resolving a conditional for somebody who is not in the group, which is
# the one finding that rules the conditional route out for a stranger. A mock
# that got this wrong would make the strategy this addon does not ship look
# perfectly safe.
mutate("tests/mockapi.lua",
       "\tif Mock.groupNames and Mock.groupNames[who] then return rest end\n\treturn nil",
       "\treturn rest",
       "the mock resolving a stranger's conditional",
       expect="a conditional aimed at a stranger on",
       script="runscenarios.py")

# The mock losing UnitBuff on the clients that have it, which would leave the
# "never called" guarantee resting on a function that is not there to call.
mutate("tests/mockapi.lua",
       "\t_G.UnitBuff = client.unitBuff and mockUnitBuff or nil",
       "\t_G.UnitBuff = nil",
       "the mock dropping UnitBuff",
       expect="the mock as mists",
       script="runscenarios.py")

# --- the first-run greeting -------------------------------------------------
# Installing the addon used to do nothing you could see. Every mutation below
# is one of the ways that silence comes back, or one of the ways a greeting
# becomes the thing people uninstall addons over: repeating itself, lying to a
# class it knows nothing about, or covering a real person with a mock-up.

# Never wired into the login at all -- the state the addon shipped in.
mutate("Core.lua",
       "\t\tns.Guard(\"Welcome\", ns.Welcome, false, off)",
       "",
       "the greeting not wired into the login",
       expect="the first login says what this is",
       script="runscenarios.py")

# It fires, and forgets. The flag is the whole of "once", and this client makes
# you /reload for every settings change.
mutate("Core.lua",
       "\tstore.welcomed = true\n",
       "\tlocal welcomed = true\n",
       "a greeting that is never written down",
       expect="the first login says what this is",
       script="runscenarios.py")

# Written down, and never read back.
mutate("Core.lua",
       "\tif store.welcomed and not force then return true end\n",
       "",
       "a greeting that never checks whether it has run",
       expect="the first login says what this is",
       script="runscenarios.py")

# Kept in the profile instead of on the character. Every character on the
# account shares one profile here, so this greets whoever logs in first and
# nobody else -- and it is invisible to a reload test, which is why there is a
# scenario with an alt in it.
mutate("Core.lua",
       "function ns.Welcome(force, offSaid)\n\tlocal store = addon.db and addon.db.char",
       "function ns.Welcome(force, offSaid)\n\tlocal store = addon.db and addon.db.profile",
       "the flag kept in the shared profile",
       expect="an alt on the same account",
       script="runscenarios.py")

# The mock handing every session its own profile, which would make the alt
# scenario above prove nothing about where the flag lives.
mutate("tests/mockapi.lua",
       "\t\t\tMock.sv.profile = Mock.sv.profile or deepcopy(defaults.profile)",
       "\t\t\tMock.sv.profile = deepcopy(defaults.profile)",
       "the mock giving every session its own profile",
       expect="an alt on the same account",
       script="runscenarios.py")

# Greeting a class the buff data has never heard of. hasClassBuffs is false for
# it exactly as it is for a rogue, and only one of the two has been told
# anything -- so this states a guess as a fact on the one screenful somebody
# reads before deciding whether to keep the addon.
mutate("Core.lua",
       "\tif not (caps.hasClassBuffs or nothingToGive) then return false end",
       "\tif false then return false end",
       "greeting a character it could not read",
       expect="an unknown class is not told it has nothing",
       script="runscenarios.py")

# Selling a macro to a class that can never have anybody on the prompt.
mutate("Core.lua",
       "\tif nothingToGive then\n",
       "\tif false then\n",
       "a tour for a class with nothing to cast",
       expect="a rogue is told the truth",
       script="runscenarios.py")

# Greeting during a fight, where a protected frame cannot be shown at all: the
# one greeting this character ever gets, spent on a picture nobody sees.
mutate("Core.lua",
       "\tif InCombatLockdown() and not nothingToGive then\n\t\tif force then",
       "\tif false then\n\t\tif force then",
       "a greeting spent on a fight",
       expect="the greeting waits for the fight to end",
       script="runscenarios.py")

# The words-only greeting made to wait for a fight as well, which would attach
# it to the end of a pull instead of to the login it belongs to. There is no
# picture in that one, and nothing about words needs the lockdown to lift.
mutate("Core.lua",
       "\tif InCombatLockdown() and not nothingToGive then",
       "\tif InCombatLockdown() then",
       "words made to wait for a picture",
       expect="a rogue is told the truth",
       script="runscenarios.py")

# And never coming back for it once the fight ends.
mutate("Core.lua",
       "\t-- character's life -- the flag is read first and this returns at once.\n"
       "\tns.Guard(\"Welcome\", ns.Welcome)\n",
       "",
       "no second chance after the fight",
       expect="the greeting waits for the fight to end",
       script="runscenarios.py")

# A mock-up put in front of a real person who is waiting. Refresh takes it
# straight back down again, so the greeting ends up pointing at a panel it did
# not put there -- in a city, which is where this addon is used.
mutate("Core.lua",
       "\tif queued > 0 then",
       "\tif false then",
       "a mock-up over somebody real",
       expect="the greeting does not cover somebody real",
       script="runscenarios.py")

# Explaining the prompt to an alt of somebody who switched the addon off. The
# profile is shared across the account, so that alt never touched the switch and
# has no way to know a setting is why nothing appears.
mutate("Core.lua",
       "\tif addon.db.profile and not addon.db.profile.enabled and not offSaid then",
       "\tif false then",
       "a greeting that hides the off switch",
       expect="a greeting on a switched-off profile",
       script="runscenarios.py")

# The preview treated as a toggle rather than as a thing to switch on. Typing
# the command twice then takes the picture away in the same breath as the line
# promising it.
mutate("Core.lua",
       "\t\t\tif ns.Prompt and not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end",
       "\t\t\tif ns.Prompt then ns.Prompt:ToggleTest() end",
       "the command undoing its own preview",
       expect="welcome can be asked for again",
       script="runscenarios.py")

# A setting written from a slash command, with the options page open behind it.
# AceConfig only reads a control while it is drawing, so without this /manners
# off leaves Enable ticked and the red notice written for that moment hidden.
mutate("Core.lua",
       "\tif REPAINT_AFTER[input] then ns.RepaintOptions() end\n",
       "",
       "a command that changes a page it leaves stale",
       expect="left an open page drawing the value it had before",
       script="runscenarios.py")

# The launcher's text back to a constant. On a broker bar that is the addon's
# name written next to the addon's icon, and the only way left to ask what state
# it is in is to click it -- which changes the answer.
mutate("Options.lua",
       '\treturn Enabled() and "Manners" or "Manners |cffff8080off|r"',
       '\treturn "Manners"',
       "a launcher that never says which state it is in",
       expect="reads the same on as off",
       script="runscenarios.py")

# And the other way it goes stale: the text is right when it is made and never
# put back in step afterwards, so it describes whatever was true at login.
mutate("Options.lua",
       "\tif broker.text ~= text then broker.text = text end",
       "\tlocal _ = text",
       "launcher text that is only ever right at login",
       expect="reads the same on as off",
       script="runscenarios.py")

# The state taken back out of the tooltip. A broker display is free to show the
# icon alone -- on the minimap that is the only shape it has -- and then the
# tooltip is the last place that can say why no prompt has appeared all evening.
mutate("Options.lua",
       """				if Enabled() then
					tooltip:AddLine("Watching for people to buff.", 0.4, 0.9, 0.4)
				else
					tooltip:AddLine("Switched off -- no prompt will appear.", 1, 0.5, 0.5)
				end
""",
       "",
       "a tooltip that never names the state",
       expect="the tooltip never names the state",
       script="runscenarios.py")

# The minimap button's own click, which is the other way the switch is thrown
# from outside the page it has a checkbox on.
mutate("Options.lua",
       "\t\t\t\t\tns.RepaintOptions()\n\t\t\t\telse",
       "\t\t\t\telse",
       "the minimap click leaving the page stale",
       expect="options page drawing the old value",
       script="runscenarios.py")

# "Show minimap button" drawn on a client with no LibDBIcon. It writes a setting
# nothing reads and calls Show on a button that was never registered: a control
# that ticks, saves, and does nothing whatever.
mutate("Options.lua",
       """					-- a disabled control would be telling anybody.
						hidden = function() return not HasMinimapButton() end,
""",
       "					-- a disabled control would be telling anybody.\n",
       "a checkbox for a button that does not exist",
       expect="on the page with no library behind it",
       script="runscenarios.py")

# The header over it, which would otherwise be a heading with nothing under it.
mutate("Options.lua",
       """					miscHeader = {
						type = "header", name = "Minimap", order = 20,
						hidden = function() return not HasMinimapButton() end,
					},""",
       """					miscHeader = { type = "header", name = "Minimap", order = 20 },""",
       "a Minimap header over an empty space",
       expect="drawn over nothing at all",
       script="runscenarios.py")

# And the same control hidden always, which satisfies everything the absence
# scenario asks for while quietly taking the minimap button off everybody's page.
mutate("Options.lua",
       """					-- a disabled control would be telling anybody.
						hidden = function() return not HasMinimapButton() end,""",
       """					-- a disabled control would be telling anybody.
						hidden = function() return true end,""",
       "the minimap control hidden from everybody",
       expect="hidden on a client that has both",
       script="runscenarios.py")

# /manners try arming macro text nobody measured. The client truncates a body
# over the limit in silence, so the expansion echoed to chat a line earlier is
# not what the button holds -- and this command exists to run one experiment.
mutate("Core.lua",
       """			if #expanded > ns.MACRO_LIMIT then
				ns.Say("  |cffff4040%d characters -- %d over the %d a macro body holds."
					.. " The client will cut it, and what runs is not what is printed"
					.. " above.|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
""",
       "",
       "arbitrary macro text armed unmeasured",
       expect="armed and echoed to chat",
       script="runscenarios.py")

# The framed border brightened towards white again. It converges on the panel
# exactly as the panel goes pale -- the failure the comment above it names.
mutate("Prompt.lua",
       "\tlocal lighten = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5",
       "\tlocal lighten = true",
       "a border that vanishes into a pale panel",
       expect="has no frame",
       script="runscenarios.py")

# The count chip back to a fixed width around a number drawn from the font
# slider. At 32 the digits are wider than the box behind them.
mutate("Prompt.lua",
       "\tlocal chipWidth = countSize * 2",
       "\tlocal chipWidth = 20",
       "a count chip narrower than its own digits",
       expect="run out of both ends",
       script="runscenarios.py")

# The same, in the other dimension.
mutate("Prompt.lua",
       "\tlocal chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))",
       "\tlocal chipHeight = math.min(14, math.max(8, p.height - 6))",
       "a count chip shorter than its own digits",
       expect="stand out of the top and bottom",
       script="runscenarios.py")

# And the room reserved beside it, which was the other fixed number: a chip that
# grows under a name that was never told to move over.
mutate("Prompt.lua",
       "\tlocal countRoom = p.showCount and (chipWidth + 8) or 10",
       "\tlocal countRoom = p.showCount and 28 or 10",
       "a name that runs under the count chip",
       expect="so the two overlap",
       script="runscenarios.py")

# The ring's length reported as the session's failure count. "The last 5 of 30"
# reads the same whether thirty things broke or thirty thousand did, and those
# want opposite responses.
mutate("Core.lua",
       "\t\tlocal total = ns.errorCount or kept",
       "\t\tlocal total = kept",
       "the ring's size printed as the failure count",
       expect="gave the size of the ring as the number of failures",
       script="runscenarios.py")

# The same wording in the block somebody pastes into a bug report, where the
# person reading it cannot ask which of the two numbers it is.
mutate("Options.lua",
       "\t\t\t:format(ns.errorCount or #ns.errors, #ns.errors)",
       "\t\t\t:format(#ns.errors, #ns.errors)",
       "a bug report counting what survived the ring",
       expect="the bug report gives the ring's size",
       script="runscenarios.py")

# The second half of a press let through whatever was on the button. An error
# between the halves re-arms the prompt at the next person, and the debounced
# press fired their macro with nothing filed -- so the refused press's parked
# record was settled by somebody else's cast.
mutate("Prompt.lua",
       "\t\t\telseif appliedKey ~= pressKey then\n\t\t\t\tPrompt:ApplyTarget(nil)\n",
       "\t\t\telseif false then\n\t\t\t\tPrompt:ApplyTarget(nil)\n",
       "a debounced press firing what it never armed",
       expect="the second half of a press fires only what the first half armed",
       script="runscenarios.py")

# A cast event a second after a refused press read as that press landing. On a
# client that names no recipient, a hand-cast on somebody else repaid the debt.
mutate("Core.lua",
       "\tif GetTime() - pending.at > SENT_SECONDS then return end\n",
       "",
       "a late cast event settling a refused press",
       expect="a cast a second after a refused press is not its answer",
       script="runscenarios.py")

# The cooldown asked after the fight is: in combat the macro cannot be disarmed,
# and a press inside the cooldown was filed against the frozen person.
mutate("Prompt.lua",
       "\t\tcooldownPressAt = (not ready) and now or nil\n\t\tif InCombatLockdown() then return end\n",
       "\t\tif InCombatLockdown() then cooldownPressAt = nil return end\n\t\tcooldownPressAt = (not ready) and now or nil\n",
       "a press in the cooldown filed during a fight",
       expect="in a fight, a press inside the cooldown is not filed",
       script="runscenarios.py")

# A press the cooldown turned away kept its PreClick stamp, and the press after
# it -- the cooldown ends mid-click as often as not -- was swallowed.
mutate("Prompt.lua",
       "\t\t\tlastPreClickAt = nil\n\t\t\tguardedEntry = current\n",
       "\t\t\tguardedEntry = current\n",
       "a guarded press swallowing the next one",
       expect="a press the cooldown turned away does not swallow the next one",
       script="runscenarios.py")

# The library's edge read through GetRange, which turns a client that will not
# answer about a stranger into "everybody is outside".
mutate("Core.lua",
       "\t\t\tlocal direct = DirectCheck(lib, edge)\n",
       "\t\t\tlocal direct = nil\n",
       "a refusal read through the library as outside",
       expect="a refusal read through the library is still a refusal",
       script="runscenarios.py")

# A rung that cannot tell about somebody offering them outright, with a working
# rung underneath that could have measured them.
mutate("Core.lua",
       "\t\tif near ~= nil then\n\t\t\tverdict = near\n\t\t\tbreak\n\t\tend\n",
       "\t\tverdict = near\n\t\tbreak\n",
       "a rung's silence letting a passer-by through",
       expect="a rung that cannot tell hands the person down",
       script="runscenarios.py")

# A pin belonging to another class wiped from the profile every character
# shares, by whichever alt logged in.
mutate("Core.lua",
       "\tif choice ~= \"auto\" and not ns.AnyClassHasBuff(choice) then\n",
       "\tif choice ~= \"auto\" and caps.class and not ns.FindBuff(caps.class, choice) then\n",
       "another class's pin reset for everybody",
       expect="wiped the mage's pin",
       script="runscenarios.py")

# An error answered the press, and the window running out answered it again:
# a second rewind, a second red flash, and "nothing at all" in chat.
mutate("Core.lua",
       "\t-- over a button long since armed at somebody else.\n\tif pending.answered then return end\n",
       "\t-- over a button long since armed at somebody else.\n",
       "a refused press flashed twice",
       expect="an error answers a press once",
       script="runscenarios.py")

# A combat press in the spell-queue window goes out when the cooldown ends,
# and dropping its bookkeeping left the person owed for a buff that landed.
mutate("Prompt.lua",
       "left <= ns.SpellQueueWindow() then\n\t\t\tready = true\n",
       "left <= ns.SpellQueueWindow() then\n",
       "a queued combat press treated as refused",
       expect="a press the client queues was treated as refused",
       script="runscenarios.py")

# The player's own queue window ignored: a press too early to be queued was
# filed against whoever the frozen macro named.
mutate("Core.lua",
       "\t\tif value and value >= 0 and value <= 1000 then return value / 1000 end\n",
       "",
       "the player's queue window ignored",
       expect="a press too early to be queued was filed",
       script="runscenarios.py")

# The range library loaded from one folder too shallow: the packager checks out
# its whole repository, the file is a folder further down, and the client skips
# a missing file without a word.
mutate("embeds.xml",
       'file="Libs\\LibRangeCheck-3.0\\LibRangeCheck-3.0\\LibRangeCheck-3.0.lua"',
       'file="Libs\\LibRangeCheck-3.0\\LibRangeCheck-3.0.lua"',
       "the range library loaded from a flat path",
       expect="the packaged LibRangeCheck-3.0 has it at",
       script="validate.py")

# LibStub called through safecall, which refuses the callable table the real
# LibStub is -- so the library rung was never built in the game.
mutate("Core.lua",
       "\t\t\tlocal stub = _G.LibStub\n"
       "\t\t\tlocal lib = type(stub) == \"table\" and type(stub.GetLibrary) == \"function\"\n"
       "\t\t\t\tand safecall(stub.GetLibrary, stub, \"LibRangeCheck-3.0\", true) or nil\n",
       "\t\t\tlocal lib = safecall(_G.LibStub, \"LibRangeCheck-3.0\", true)\n",
       "the range library fetched through safecall",
       expect="the range library is found through a LibStub shaped like the game's",
       script="runscenarios.py")

# The duel prompt reported at eight yards whatever the race, where a tauren's is
# six and an undead's seven.
mutate("Core.lua",
       "\treturn INTERACT_DUEL_RACE[race] or 8\n",
       "\treturn 8\n",
       "the duel prompt at eight yards for every race",
       expect="the duel prompt's distance follows the player's race",
       script="runscenarios.py")

# A warrior's scan measuring strangers it can never offer anything, which fed
# the counts and dropped a silent rung.
mutate("Core.lua",
       "\t\tif reason == \"nearby\" and groupOnly then return end\n",
       "",
       "a warrior's scan measuring strangers",
       expect="strangers a warrior can never offer were measured",
       script="runscenarios.py")

# The summary describing a stranger filter to a class that never reaches one.
mutate("Core.lua",
       "\tif ns.OnlyReachesGroup() then\n"
       "\t\treturn out .. \" -- your buffs reach only your group, so nobody is measured\"\n"
       "\tend\n",
       "",
       "a warrior told strangers are measured",
       expect="the line does not say a warrior's buffs reach only the group",
       script="runscenarios.py")

# A partyOnly buff judged on "in the group", which in a raid is all forty:
# Battle Shout offered to thirty-five raiders it cannot reach.
mutate("Core.lua",
       "\t\tif buff.partyOnly and not opts.inParty then return false end\n",
       "\t\tif buff.partyOnly and not opts.inGroup then return false end\n",
       "a shout offered to the whole raid",
       expect="Battle Shout in a raid reaches the warrior's own subgroup",
       script="runscenarios.py")

# The roster fallback taking everybody in the raid for the player's subgroup,
# on a client without UnitInSubgroup.
mutate("Core.lua",
       "\treturn theirs ~= nil and theirs == ours\n",
       "\treturn true\n",
       "the raid roster read as one subgroup",
       expect="reaches the warrior's own subgroup (the raid roster)",
       script="runscenarios.py")

# The vanilla subgroup rule carried onto a set whose shouts reach the raid.
mutate("Core.lua",
       "\tif not ns.PARTY_IS_SUBGROUP then\n",
       "\tif false then\n",
       "a raid-wide shout held to one subgroup",
       expect="a raid-wide shout reaches the whole raid",
       script="runscenarios.py")

# The favour line asking whether they are in the raid rather than whether the
# shout reaches them.
mutate("Core.lua",
       "\tlocal inParty = seen.sameParty\n"
       "\tif inParty == nil then inParty = SameParty(seen.name) end\n",
       "\tlocal inParty = type(safecall(_G.UnitInRaid, seen.name)) == \"number\"\n",
       "a raider in another subgroup promised the prompt",
       expect="a favour from another subgroup was announced as on the prompt",
       script="runscenarios.py")

# A shout's reach left to IsSpellInRange, which has nothing to say about a spell
# with no target: a party member sixty yards off is offered it.
mutate("Core.lua",
       "\t\tif ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end\n",
       "",
       "a shout offered at any distance",
       expect="a party member sixty yards away was offered Battle Shout",
       script="runscenarios.py")

# A shout nothing measured taken as repaying the person named.
mutate("Core.lua",
       "\tif not unheard then ns.SettleFavour(pending.name) end\n",
       "\tns.SettleFavour(pending.name)\n",
       "an unmeasured shout counted as repaid",
       expect="a shout nothing could say reached them counted as repaying",
       script="runscenarios.py")

# A favour recorded and promised when nothing we cast is any use to them.
mutate("Core.lua",
       "\tif not ns.CouldOffer(hasMana, true) then\n",
       "\tif false then\n",
       "a useless favour recorded",
       expect="a favour nothing can repay was recorded",
       script="runscenarios.py")

# A favour announced by a character with every spell switched off.
mutate("Core.lua",
       "\tif #ns.CastableBuffs() == 0 then return end\n",
       "",
       "a favour noted with every spell off",
       expect="(every spell switched off): a favour was announced with nothing to offer",
       script="runscenarios.py")

# A favour announced by a character whose pinned spell is not learned.
mutate("Core.lua",
       "\tlocal pinned = ns.PinnedBuff()\n"
       "\tif pinned and not ns.IsBuffKnown(pinned) then return end\n",
       "",
       "a favour noted under an unlearned pin",
       expect="(the pinned spell not learned): a favour was announced with nothing",
       script="runscenarios.py")

# A debt read on the stamp it was filed with, so a shorter window changes
# nothing until a reload.
mutate("Core.lua",
       "\treturn math.min(entry.expires, entry.at + window)\n",
       "\treturn entry.expires\n",
       "a shorter window ignored by live debts",
       expect="a minute-old debt outlived a thirty-second window",
       script="runscenarios.py")

# One reader going back to the stamp: the queue.
mutate("Core.lua",
       "owed[full] and LiveExpiry(owed[full]) > now",
       "owed[full] and owed[full].expires > now",
       "the queue reading a debt's first stamp",
       expect="a debt older than the window was still offered as owed",
       script="runscenarios.py")

# And /manners debug.
mutate("Core.lua",
       "\t\t\tlocal expires = LiveExpiry(entry)\n\t\t\tif expires > now then\n\t\t\t\tpending",
       "\t\t\tlocal expires = entry.expires\n\t\t\tif expires > now then\n\t\t\t\tpending",
       "the debug listing reading a debt's first stamp",
       expect="/manners debug still lists a debt older than the window",
       script="runscenarios.py")

# A reload restarting the window from the login rather than the favour.
mutate("Core.lua",
       "\t\t\tlocal left = math.min(entry.expires, entry.at + window) - wall\n",
       "\t\t\tlocal left = math.min(entry.expires - wall, window)\n",
       "a reload restarting the window",
       expect="a debt older than the window does not survive a reload",
       script="runscenarios.py")

# A pinned spell dropped by its own switch, which the page hides while it is
# pinned: everything off and Fortitude pinned offered nobody anything.
mutate("Core.lua",
       "\t\t\tand (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))\n",
       "\t\t\tand not (db and db.buff.skip and db.buff.skip[buff.key])\n",
       "a pinned spell silenced by its own switch",
       expect="(everything off, Fortitude pinned): the pinned spell is not among the castable",
       script="runscenarios.py")

# The paladin's automatic pick naming a blessing that is switched off, at login
# and everywhere else "the spell you are about to cast" is said.
mutate("Core.lua",
       "\t\tif buff and ns.IsBuffKnown(buff) and not buff.neverAuto\n"
       "\t\t\tand not (db.buff.skip and db.buff.skip[key]) then\n",
       "\t\tif buff and ns.IsBuffKnown(buff) then\n",
       "a switched-off blessing named at login",
       expect="(Wisdom switched off): the login line names a spell that is switched off",
       script="runscenarios.py")

# Every spell switched off, reported as none learned.
mutate("Core.lua",
       '("nothing -- " .. ns.NothingToCast())',
       '"nothing -- no buff learned"',
       "switched-off spells reported as unlearned",
       expect="three learned spells, all switched off, reported as none learned",
       script="runscenarios.py")

# And greeted with a tour of a prompt that will never appear.
mutate("Core.lua",
       "\tif caps.anyKnown and not ns.ResolveBuff(true) then\n",
       "\tif false then\n",
       "a greeting promising a prompt nothing fills",
       expect="the greeting promised a prompt nothing will ever fill",
       script="runscenarios.py")

# An unlearned pin falling through to Automatic, so the login line names a
# spell the pin keeps from ever being cast.
mutate("Core.lua",
       "\tif pinned then return ns.IsBuffKnown(pinned) and pinned or nil end\n",
       "\tif pinned and ns.IsBuffKnown(pinned) then return pinned end\n",
       "an unlearned pin replaced by Automatic",
       expect="(Divine Spirit pinned, not learned): the login line names a spell the pin",
       script="runscenarios.py")

# The same pin, named nowhere: the line then blames something else.
mutate("Core.lua",
       "\tif pinned and not ns.IsBuffKnown(pinned) then\n"
       "\t\treturn (\"%s is pinned and not learned on this character\"):format(ns.BuffName(pinned))\n"
       "\tend\n",
       "",
       "an unlearned pin not named at login",
       expect="(Divine Spirit pinned, not learned): the login line",
       script="runscenarios.py")

# Another paladin's blessing counted as one of ours: Might never offered to a
# warrior wearing somebody else's Kings.
mutate("Core.lua",
       "\t\t\t\tif held == true and mine == false then\n",
       "\t\t\t\tif false then\n",
       "another paladin's blessing taken as ours",
       expect="(a warrior with another paladin's Kings): read: offered false, expected might",
       script="runscenarios.py")

# The same, three seconds later: the cache remembering that there was a
# blessing and forgetting whose it was.
mutate("Core.lua",
       "\t\treturn cached.has, cached.expires and (cached.expires - now) or nil, cached.mine\n",
       "\t\treturn cached.has, cached.expires and (cached.expires - now) or nil\n",
       "the aura cache forgetting whose blessing it was",
       expect="(a warrior with another paladin's Kings): cached: offered false",
       script="runscenarios.py")

# An aura that names nobody taken as somebody else's, which is how our own
# blessing would be walked over on a client that will not say.
mutate("Core.lua",
       "\t\t\t\tlocal source = plain(aura.sourceUnit)\n"
       "\t\t\t\tif type(source) == \"string\" then\n",
       "\t\t\t\tlocal source = plain(aura.sourceUnit)\n"
       "\t\t\t\tmine = false\n"
       "\t\t\t\tif type(source) == \"string\" then\n",
       "a blessing from nobody named taken as another's",
       expect="(a warrior with Kings from nobody named)",
       script="runscenarios.py")

# A refused aura read reported as a definite no, which promotes a target over
# somebody who buffed you.
mutate("Core.lua",
       "\tif not has and refused then has = nil end\n",
       "",
       "a refused aura read taken as a no",
       expect="(an id declared secret): a reading the client refused came back as false",
       script="runscenarios.py")

# The two halves of "refused" on their own: an id the client declared secret...
mutate("Core.lua",
       "\t\tif info.secrecy[id] == true then\n\t\t\trefused = true\n\t\telse\n",
       "\t\tif info.secrecy[id] == true then\n\t\telse\n",
       "a secret aura id passed over as absent",
       expect="(an id declared secret): a reading the client refused came back as false",
       script="runscenarios.py")

# ...and a read that throws.
mutate("Core.lua",
       "\t\t\tif not ok or (issecretvalue and issecretvalue(aura)) then\n",
       "\t\t\tif false then\n",
       "an aura read that throws taken as absent",
       expect="(a read that throws): a reading the client refused came back as false",
       script="runscenarios.py")

# The login line saying "watching for buffs" on a profile that is switched off.
mutate("Core.lua",
       "\t\telseif off then\n",
       "\t\telseif false then\n",
       "the login line watching while switched off",
       expect="said it is watching for buffs while switched off",
       script="runscenarios.py")

# And the greeting saying it again, one line under the login line.
mutate("Core.lua",
       "\tif addon.db.profile and not addon.db.profile.enabled and not offSaid then",
       "\tif addon.db.profile and not addon.db.profile.enabled then",
       "switched off said twice at a first login",
       expect="said it is switched off 2 times",
       script="runscenarios.py")

# A damaged colour repaired with the defaults' own table, which the next
# profile switch strips bare -- a white panel on every profile after it.
mutate("Core.lua",
       "\t\t\tp[key] = { d[1], d[2], d[3], d[4] }\n",
       "\t\t\tp[key] = d\n",
       "a repaired colour sharing the default's table",
       expect="the switch emptied the default colour itself",
       script="runscenarios.py")

# An emptied phrase box kept as typed, and refilled later by a size slider.
mutate("Options.lua",
       "\t\t\t\t\t\t\tif type(value) ~= \"string\" or value:match(\"^%s*$\") then\n",
       "\t\t\t\t\t\t\tif false then\n",
       "an emptied phrase box kept empty",
       expect="the box went on showing",
       script="runscenarios.py")

# The anchor carry-over moving a prompt without a word...
mutate("Core.lua",
       "\t\t\tns.anchorCarriedNote = true\n",
       "",
       "a carried anchor moved in silence",
       expect="the prompt was moved onto a new anchor and chat said nothing",
       script="runscenarios.py")

# ...and a profile switch that carries one not saying so.
mutate("Core.lua",
       "\tns.SayAnchorCarried()\n\tns.Prompt:ApplyStyle()\n",
       "\tns.Prompt:ApplyStyle()\n",
       "a carried anchor on a switch moved in silence",
       expect="a profile switch moved the prompt onto a new anchor",
       script="runscenarios.py")

# /manners debug saying "nobody has buffed you" while switched off...
mutate("Core.lua",
       "\t\t\tif not db.enabled then\n\t\t\t\tself:Print(\"  not watching for favours",
       "\t\t\tif false then\n\t\t\t\tself:Print(\"  not watching for favours",
       "debug claiming nobody buffed you while off",
       expect="(switched off): debug said nobody has buffed you",
       script="runscenarios.py")

# ...and while the favour source is unticked...
mutate("Core.lua",
       "\t\t\telseif not db.sources.owed then\n",
       "\t\t\telseif false then\n",
       "debug claiming nobody buffed you, source off",
       expect="(favours not watched): debug said nobody has buffed you",
       script="runscenarios.py")

# ...and never naming the off switch at all.
mutate("Core.lua",
       "\t\tif not db.enabled then\n\t\t\tself:Print(\"|cffff8080switched OFF",
       "\t\tif false then\n\t\t\tself:Print(\"|cffff8080switched OFF",
       "debug silent about the off switch",
       expect="debug never said the addon is switched off",
       script="runscenarios.py")

# /manners try guessing "target" for a {unit} the person has not got...
mutate("Core.lua",
       "\tif entry and not entry.unit and text:find(\"{unit}\", 1, true) then\n",
       "\tif false then\n",
       "try {unit} falling back to your target",
       expect="a macro was armed with {unit} guessed at",
       script="runscenarios.py")

# ...and {first} for a name that is one word already.
mutate("Core.lua",
       "(ns.FirstName(entry.name) or entry.targetName or entry.name) or \"target\")",
       "(ns.FirstName(entry.name)) or \"target\")",
       "try {first} falling back to your target",
       expect="(a one-word name): a token became your own target",
       script="runscenarios.py")

# The tooltip promising a run the button was left empty for.
mutate("Prompt.lua",
       "\t\tif not text then\n\t\t\tout[#out + 1] = (\"|cffffcc66Does nothing:|r",
       "\t\tif false then\n\t\t\tout[#out + 1] = (\"|cffffcc66Does nothing:|r",
       "try tooltip promising an empty button",
       expect="the tooltip promised a run the button was left empty for",
       script="runscenarios.py")

# /manners look printing a withheld aura check as a readable no.
mutate("Core.lua",
       "\t\t\tif not found and (unreadable or #withheld > 0) then\n",
       "\t\t\tif false then\n",
       "look printing a withheld check as false",
       expect="a check the client withheld was printed as a readable no",
       script="runscenarios.py")

# The help describing a switch that starts on as the thing it does.
mutate("Core.lua",
       "help = \"switch handing your target back after buffing on or off\"",
       "help = \"hand your target back after buffing\"",
       "help describing restore as an action",
       expect="the help describes restore as an action",
       script="runscenarios.py")

# /manners restore in a fight, silent about the frozen macro...
mutate("Core.lua",
       "\t\t\t.. (InCombatLockdown() and (\" -- \" .. FROZEN_UNTIL_FIGHT_ENDS) or \"\"))\n",
       ")\n",
       "restore in a fight silent about the freeze",
       expect="/manners restore in a fight never said",
       script="runscenarios.py")

# ...and /manners try sending a press to it.
mutate("Core.lua",
       "\t\t\tif InCombatLockdown() then\n\t\t\t\tself:Print(\"It \" .. FROZEN_UNTIL_FIGHT_ENDS",
       "\t\t\tif false then\n\t\t\t\tself:Print(\"It \" .. FROZEN_UNTIL_FIGHT_ENDS",
       "try in a fight sending a press to the old macro",
       expect="/manners try /cast Frost Nova sent a press to a frozen macro",
       script="runscenarios.py")

# The When you click tab saying nothing in a fight.
mutate("Options.lua",
       "\t\t\t\t\t\thidden = function() return not InCombatLockdown() end,\n"
       "\t\t\t\t\t\tname = \"|cffffd100In combat.|r Blizzard freezes the macro",
       "\t\t\t\t\t\thidden = function() return true end,\n"
       "\t\t\t\t\t\tname = \"|cffffd100In combat.|r Blizzard freezes the macro",
       "click tab silent in a fight",
       expect="the When you click tab says nothing about the fight",
       script="runscenarios.py")

# /manners unlock in a fight sending you to drag.
mutate("Core.lua",
       "\t\tif db.enabled and InCombatLockdown() then\n",
       "\t\tif false then\n",
       "unlock in a fight saying drag",
       expect="sent you to drag a prompt the client will not move in a fight",
       script="runscenarios.py")

# The combat hold painted only by the handler's own Refresh, which runs before
# lockdown and so never paints it.
mutate("Core.lua",
       "\tC_Timer.After(0, function()\n"
       "\t\tif ns.Prompt then ns.Guard(\"combat hold\", ns.Prompt.Refresh, ns.Prompt) end\n"
       "\tend)\n",
       "",
       "combat hold waiting for the next scan",
       expect="the prompt admits it is frozen in combat: the panel kept full brightness",
       script="runscenarios.py")

# A refusal with a guid missing on one side matched to the only settle in the
# window. A new attempt refused with nothing parked -- a mashed press in a
# fight, the same buff on an action bar -- undid a press that had landed.
mutate("Core.lua",
       "\tif castGUID == nil then return nil end\n"
       "\tfor i, record in ipairs(settledRecent) do\n"
       "\t\t-- Both sides named the cast. That is an answer, not a guess, and a\n"
       "\t\t-- guid naming none of ours means the failure was not ours at all.\n"
       "\t\tif record.castGUID == castGUID then return i end\n"
       "\tend\n"
       "\treturn nil\n",
       "\tlocal match, ambiguous\n"
       "\tfor i, record in ipairs(settledRecent) do\n"
       "\t\tif castGUID ~= nil and record.castGUID ~= nil then\n"
       "\t\t\tif record.castGUID == castGUID then return i end\n"
       "\t\telseif match then ambiguous = true else match = i end\n"
       "\tend\n"
       "\tif ambiguous then return nil end\n"
       "\treturn match\n",
       "a guid-less refusal matched to the only settle",
       expect="a refusal nothing tied to the press that landed put the debt back",
       script="runscenarios.py")

# The settle after an error inside the window saying nothing, so chat is left
# on "was not buffed" about a buff that went out.
mutate("Core.lua",
       "\telseif pending.answered then\n",
       "\telseif false then\n",
       "an error's line left standing after the settle",
       expect="chat was left saying the buff failed after it went out",
       script="runscenarios.py")

# The global cooldown tracked and never read, so every cast -- a healthstone,
# Counterspell -- arms a second and a half of "not ready".
mutate("Core.lua",
       "\tlocal left = GlobalCooldownLeft(now) or (castBlockedUntil - now)\n",
       "\tlocal left = castBlockedUntil - now\n",
       "the global cooldown guessed where it can be read",
       expect="the client said the global cooldown was idle",
       script="runscenarios.py")

# And a spell the client says is off the global cooldown arming the guess
# anyway, where 61304 will not answer.
mutate("Core.lua",
       "\t\t\tif plain(info.isOnGCD) == false then return end\n",
       "",
       "an off-GCD spell arming the fallback",
       expect="a spell the client says is off the global cooldown still held the prompt",
       script="runscenarios.py")

# An abandoned press announced as "was not buffed", though nothing says so.
mutate("Core.lua",
       '\tSayStillOwed(pending.name, "another press arrived before the game answered that one",\n'
       '\t\t"no answer yet for the press on |cffffffff%s|r -- another press arrived first.")\n',
       '\tSayStillOwed(pending.name, "another press arrived before the game answered that one")\n',
       "an unanswered press called a miss",
       expect="a press the game had not answered yet was announced as a miss",
       script="runscenarios.py")

# The repaid line for a shout printing a field name from Buffs.lua.
mutate("Core.lua",
       '\t\tsaid = "%s is cast on you, not on them, so whether it reached them depends on"\n'
       '\t\t\t.. " where they were standing",\n',
       '\t\tsaid = "our spell went out, but a selfCast buff has no target at all -- whether"\n'
       '\t\t\t.. " it reached them depends on where they were standing",\n',
       "a code name in the repaid line",
       expect="chat showed the player a name from the code",
       script="runscenarios.py")

# The press rule believing the flash only while it is live, so a press after
# it timed out -- its words still on the panel -- went to the entry under it.
mutate("Prompt.lua",
       "\tif outcomePainted then return outcomePainted end\n",
       "\tif self:OutcomeLive() then return outcomeName end\n",
       "a press under an old flash going to the next person",
       expect="cast at Bert (",
       script="runscenarios.py")

# And the flash left for the next scan to take off.
mutate("Prompt.lua",
       "\t\t\tif gen ~= outcomeGen then return end\n"
       "\t\t\tns.Guard(\"prompt outcome expiry\", Prompt.Refresh, Prompt)\n",
       "\t\t\tif gen ~= outcomeGen then return end\n",
       "the red flash waiting for a scan",
       expect="the red flash outlived its own six tenths of a second",
       script="runscenarios.py")

# A right-click under the flash skipping whoever is armed underneath it.
mutate("Prompt.lua",
       "\t\t\tlocal victim = Prompt:PanelName() or (current and current.name)\n",
       "\t\t\tlocal victim = current and current.name\n",
       "a right-click skipping the person under the flash",
       expect="skipped Bert instead",
       script="runscenarios.py")

# The press asking the fuse's clock rather than the panel, so a press before
# any scan lit the fuse, or after it burnt out, disarmed a named prompt.
mutate("Prompt.lua",
       "\t\tif not top and current and not Retired(current, now) and named == current.name then\n",
       "\t\tif not top and emptyAt and (now - emptyAt) < EMPTY_FUSE_SECONDS"
       " and not Retired(current, now) then\n",
       "a press on a named prompt going nowhere",
       expect="did nothing and said nothing",
       script="runscenarios.py")

# And the panel left up past its fuse until a scan came round.
mutate("Prompt.lua",
       "\t\tC_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()\n"
       "\t\t\tns.Guard(\"fuse repaint\", Prompt.Refresh, Prompt)\n",
       "\t\tC_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()\n",
       "the fuse burning out with nobody to notice",
       expect="the fuse burnt out and the panel stayed up",
       script="runscenarios.py")

# A press while switched off answered with "nobody to buff".
mutate("Prompt.lua",
       "\t\t\tif db and not db.enabled then\n"
       "\t\t\t\tns.addon:Print(\"Manners is |cffff8080switched off|r",
       "\t\t\tif false then\n"
       "\t\t\t\tns.addon:Print(\"Manners is |cffff8080switched off|r",
       "a press while switched off saying nobody to buff",
       expect="never said Manners is switched off",
       script="runscenarios.py")

# Your own target handed back to whoever came before them.
mutate("Prompt.lua",
       '\tlocal restore = ns.db.profile.filters.restoreTarget == true and entry.unit ~= "target"\n',
       "\tlocal restore = ns.db.profile.filters.restoreTarget == true\n",
       "your own target switched away after the buff",
       expect="hands the target to whoever came before",
       script="runscenarios.py")

# The tooltip reading the setting instead of what the macro does.
mutate("Prompt.lua",
       "\t\tlocal _, restore = CastLines(entry)\n\t\tif restore then\n",
       "\t\tif ns.db.profile.filters.restoreTarget then\n",
       "the tooltip promising a hand-back the macro skips",
       expect="the tooltip promises to hand back a target the macro keeps",
       script="runscenarios.py")

# A release ending a drag that never started.
mutate("Prompt.lua",
       "\t\tif not dragging then return end\n",
       "",
       "a drag that never started being ended",
       expect="slid a few pixels ended a move",
       script="runscenarios.py")

# A drag held into a pull left for the release, which comes in the fight.
mutate("Core.lua",
       '\tif ns.Prompt then ns.Guard("drag at fight start", ns.Prompt.FinishDragForFight, ns.Prompt) end\n',
       "",
       "a drag held into a pull",
       expect="never had its position saved",
       script="runscenarios.py")

print()
print("after restore:")
# This file edits the addon in place. A restore that did not happen leaves a
# mutation in the working tree and every later run measuring it, so the check
# that the files came back is as load-bearing as the mutations themselves.
not_restored = []
for script in SUITES:
    line, clean = tally(script)
    print("  %-20s %s" % (script, line))
    if not clean:
        not_restored.append(script)

if dead_anchors or missed or misattributed or not_restored:
    print()
    for label in dead_anchors:
        print("ANCHOR GONE: " + label)
    for label in missed:
        print("MISSED: " + label)
    # The failure this file used to report as a pass. The run went red, so the
    # old CAUGHT column lit up -- but about something else entirely, which
    # leaves the check named here unexercised and unproven.
    for label, expect, complaints in misattributed:
        print("WRONG CHECK: " + label + " -- nothing said " + repr(expect))
        for c in complaints:
            print("             instead: " + c.strip()[:96])
    for script in not_restored:
        print("NOT RESTORED: " + script + " is red on a tree that started green")
    # The four suites are the project's only gate. One of them reporting a
    # check that is switched off as success is how the stale-macro guarantee
    # stayed dead through three releases.
    print("RESULT: the suite is not proving what it claims")
    sys.exit(1)

print()
print("RESULT: every mutation was caught")
