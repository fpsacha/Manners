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
    """The suite's own verdict line, and whether it is a clean one."""
    lines = [l for l in out.split("\n") if l.startswith(("errors:", "failures:"))]
    line = lines[0] if lines else "?"
    return line, line in ("errors: 0", "failures: 0")


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
       "		if not top and FuseStillBurning(now) then return end\n",
       "",
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
       """	local iconMax = math.max(12, (p.height or ns.defaults.profile.prompt.height) - 8)
	if p.iconSize > iconMax then p.iconSize = iconMax end""",
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
       "		if ns.IsBuffKnown(buff) and not (db and db.buff.skip and db.buff.skip[buff.key]) then",
       "		if ns.IsBuffKnown(buff) then",
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
       """				hidden = function()
					local s = S()
					return s.owed or s.group or s.strangers
				end,""",
       "				hidden = function() return true end,",
       "no warning for a queue that can never fill",
       expect="all three sources are off and the page says nothing",
       script="runscenarios.py")

# 39. and the quietest of them: a pinned spell you have not learned. The pin is
#     the only spell considered, so nobody is offered anything at all -- and it
#     is deliberately not reset for you, because a failed spell probe must not
#     rewrite a setting.
mutate("Options.lua",
       'hidden = function() return B().choice == "auto" end,',
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
mutate("Options.lua",
       "hidden = function() return not InCombatLockdown() end,",
       "hidden = function() return true end,",
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
	if ns.RefreshOptionsDisplay then
		ns.Guard("options repaint", ns.RefreshOptionsDisplay)
	end
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
	SayStillOwed(pending.name, "another press arrived before the game answered that one")""",
       """	ns.pendingClick = nil
	if GetTime() - pending.at > SETTLE_SECONDS then return end
	SayStillOwed(pending.name, "another press arrived before the game answered that one")""",
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
		local late = UnsettleLateRefusal(spellId)
		if late then ShowOutcome("failed", late, "the game refused the cast") end
	end
""",
       "",
       "a refusal arriving after the send",
       expect="a cast the server refused stayed filed as a favour repaid",
       script="runscenarios.py")

# 57. and the check that keeps it honest. UNIT_SPELLCAST_FAILED is the only
#     refusal that names its spell, so it is the only one that can tell our own
#     cast being refused from anything else on the bar failing in the same
#     second -- and without it a confirmed buff is undone by somebody else's
#     miss.
mutate("Core.lua",
       "\tif not SpellIsCertainlyOurs(spellId, settled.buffKey) then return nil end\n",
       "",
       "a refusal credited to the wrong spell",
       expect="an unrelated spell failing undid a confirmed cast",
       script="runscenarios.py")

# 57b. the same check read the permissive way round. SpellIsOurs treats a
#      missing id as ours on purpose, because everywhere else a withheld number
#      must not make a favour permanent -- but this is the one direction where
#      no evidence has to mean no action, and borrowing that leniency reopens a
#      repaid debt on every failure the client will not name.
mutate("Core.lua",
       "	if not SpellIsCertainlyOurs(spellId, settled.buffKey) then return nil end\n",
       "	if not SpellIsOurs(spellId, settled.buffKey) then return nil end\n",
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

# 57c. one slot with no identity on it. Two settles inside one window and the
#      second overwrote the first, so a refusal owed to the first press was
#      applied to the second: the wrong person's repayment undone, and a line
#      in the log about a cast that was never refused.
mutate("Core.lua",
       """	local previous = lastSettleAt
	lastSettleAt = record.at
	if previous and record.at - previous <= SETTLE_SECONDS then
		settledClick = nil
		return
	end
	settledClick = record""",
       "\tsettledClick = record",
       "two settled casts kept in one slot",
       expect="one refusal was applied to one of two casts it cannot be told apart from",
       script="runscenarios.py")

# 57d. and the version that tracks only the record, which is the shape this
#      started as: two settles clear the slot and the third refills it, while
#      the second cast is still unanswered and can refuse into it.
mutate("Core.lua",
       """	local previous = lastSettleAt
	lastSettleAt = record.at
	if previous and record.at - previous <= SETTLE_SECONDS then""",
       """	local previous = settledClick and settledClick.at
	lastSettleAt = record.at
	if previous and record.at - previous <= SETTLE_SECONDS then""",
       "the cleared slot refilled by the next settle",
       expect="a run of settles cleared the slot and then refilled it",
       script="runscenarios.py")

# 57e. a debt raised, written to disk and announced with the addon switched
#      off. NoteFavour refuses to do exactly that at the other end of the same
#      write, calling it the same lie told louder.
mutate("Core.lua",
       """	local db = addon.db and addon.db.profile
	if not db or not db.enabled or not db.sources.owed then
		settledClick = nil
		return nil
	end

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
				local held, remaining = has(buff)""",
       """				-- class it is safest on -- see the top-up below.
				local held = has(buff)""",
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

# 78. AceConfigRegistry called straight from a setter. It is fetched with the
#     silent flag precisely because it may be absent, and this was the one
#     reader that did not check -- so the absence it is fetched for threw, from
#     inside a set, with somebody's finger on the slider.
mutate("Options.lua",
       "\t\t\t\t\t\t\tns.RefreshOptionsDisplay()\n\t\t\t\t\t\tend,",
       "\t\t\t\t\t\t\tAceConfigRegistry:NotifyChange(ADDON)\n\t\t\t\t\t\tend,",
       "a setter calling a library that may be absent",
       expect="moving the icon slider threw",
       script="runscenarios.py")

# 79. the clamp the icon slider never ran. The bound cannot live on the control
#     -- AceConfig rejects the whole table for a function where it wants a
#     number -- so the setter is the only place left to apply it, and it did
#     not, under a notice claiming the icon was being held.
mutate("Options.lua",
       # Anchored on the comment that follows it: the height slider's setter is
       # the same three lines, sits earlier in the file, and would otherwise be
       # the one this replaced -- which is a mutation of a different check.
       "\t\t\t\t\t\t\tns.ClampSettings()\n\t\t\t\t\t\t\trestyle()\n\t\t\t\t\t\t\t-- Re-read it",
       "\t\t\t\t\t\t\t-- Re-read it",
       "an icon slider that outgrows its panel",
       expect="dragging the icon slider left an icon taller",
       script="runscenarios.py")

# 80. the description that named three reason colours out of four, leaving out
#     the one most people see most often.
mutate("Options.lua",
       'desc = "Green for somebody you targeted yourself, amber when returning a"',
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
