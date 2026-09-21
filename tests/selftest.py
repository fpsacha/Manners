"""Prove the harness still detects the fault classes that actually happened,
by reintroducing each one, running, and putting the file back.

A suite that cannot go red proves nothing, so this is run whenever the addon
is restructured -- a refactor can quietly move the code a check depends on.
"""
import subprocess, shutil, sys, os

DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(DIR, "tests")


SUITES = ("runharness.py", "runscenarios.py")


def run(script):
    r = subprocess.run([sys.executable, os.path.join(TESTS, script)],
                       capture_output=True, text=True)
    return r.stdout


def tally(script):
    """The suite's own verdict line, and whether it is a clean one."""
    lines = [l for l in run(script).split("\n") if l.startswith(("errors:", "failures:"))]
    line = lines[0] if lines else "?"
    return line, line in ("errors: 0", "failures: 0")


dead_anchors = []
missed = []


def mutate(filename, old, new, label, script="runharness.py"):
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
        caught = ("errors: 0" not in out) and ("failures: 0" not in out)
        if not caught:
            missed.append(label)
        print("%-44s %s" % (label, "CAUGHT" if caught else "*** MISSED ***"))
        if caught:
            for line in out.split("\n"):
                if line.strip().startswith("  ") and line.strip():
                    print("      " + line.strip()[:96])
                    break
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
       "cross-file local call (the `plain` bug)")

# 2. an event this client does not have -- the scanner-never-started bug
mutate("Core.lua",
       '"SPELLS_CHANGED",',
       '"LEARNED_SPELL_IN_TAB",',
       "unknown event (scanner never started)")

# 3. a misspelled API, the general case
mutate("Core.lua",
       "local maxMana = plain(UnitPowerMax(unit, MANA))",
       "local maxMana = plain(UnitPowerMaxx(unit, MANA))",
       "misspelled WoW API")

# 4. a setting left unvalidated -- a stale profile falls through every branch
mutate("Core.lua",
       '\toneOf(p, "style", { glass = true, blizzard = true, minimal = true }, "glass")',
       "",
       "unvalidated enum setting",
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
       script="runscenarios.py")

# 6. the macro rebuilt from scratch on every repaint -- the reason appliedKey
#    exists at all. A dead optimisation is not a bug, but a dead check is: this
#    one went unnoticed for three releases while the name sat unread in four
#    assignments.
mutate("Prompt.lua",
       "	if key == appliedKey then return end",
       "	if false then return end",
       "macro re-armed on every repaint",
       script="runscenarios.py")

# 7. a debt written in GetTime() units, which mean nothing after a reload
mutate("Core.lua",
       "	local wall = plain(time and time())",
       "	local wall = GetTime()",
       "debts saved on a clock that restarts",
       script="runscenarios.py")

# 8. the aura baseline reused without being emptied. The reuse is a deliberate
#    optimisation -- this runs on every UNIT_AURA -- and the wipe is the only
#    thing that keeps it from becoming a list of everything you have ever held.
mutate("Core.lua",
       "function ns.ScanOwnBuffs()\n\twipe(present)\n",
       "function ns.ScanOwnBuffs()\n",
       "an aura baseline that never forgets",
       script="runscenarios.py")

# 9. the one line that puts the console in SavedVariables. The file says in two
#    places that a session can be read off disk afterwards; without this it
#    cannot, and nothing about that is visible in game.
mutate("Core.lua",
       "\tMannersDB.console = ns.console\n",
       "",
       "the console never reaching the disk",
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
       script="runscenarios.py")

# 11. and the same mistake at the other end of the scan. A refusal of the
#     trailing slots leaves no readable aura behind the silence, so there is no
#     evidence of it anywhere in the reading; pruning on that one scan drops
#     precisely the auras it failed to read and invents a favour out of each of
#     them the moment they come back.
mutate("Core.lua",
       "\t\t\tif not present[instanceId] and not lastPresent[instanceId] then\n",
       "\t\t\tif not present[instanceId] then\n",
       "an aura baseline pruned off one scan",
       script="runscenarios.py")

# 12. one line, and it looks like a tidy-up: the evidence the scan collects is
#     recorded for /manners debug either way, so dropping the early return
#     changes nothing a reader can see. It changes what counts as a reading. A
#     scan the client refused outright currently never becomes one of the two
#     that have to agree, so a recognisable blackout can last all day without
#     ever agreeing with itself; without this it corroborates its own refusal on
#     the second scan and empties the baseline.
mutate("Core.lua",
       "\tif doubt then return end\n",
       "",
       "a refusal that corroborates itself",
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
       script="runscenarios.py")

# 14. and the same walk-off by the other door. A blessing on cooldown is one
#     that was offered moments ago; stepping past it to the next one replaces
#     what the last click gave. The carve-out let a readable client do exactly
#     that, on the strength of an aura reading taken before the cast.
mutate("Core.lua",
       "\t\tif onCooldown then return nil, nil end\n",
       "\t\tif onCooldown and not allRead then return nil, nil end\n",
       "a blessing replaced while it is on cooldown",
       script="runscenarios.py")

# 15. one pending slot, overwritten without a word. Everything the buried press
#     wrote on the assumption it landed stays standing, with nothing left that
#     could ever take it back.
mutate("Prompt.lua",
       "\t\tns.AbandonPendingClick()\n",
       "",
       "a pending click discarded silently",
       script="runscenarios.py")

# 16. the regression: any error the game raises settling our click, and now
#     filing name evidence with it. Two unrelated errors and that person is on
#     bare first-name targeting for the session -- and the cast that really did
#     go out has nothing left to settle.
mutate("Core.lua",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ns.pendingClick = nil
		return nil
	end
	RewindClick(pending)
	return pending.name
end""",
       """	if GetTime() - pending.at > SETTLE_SECONDS then
		ns.pendingClick = nil
		return nil
	end
	RewindClick(pending)
	NameMissed(pending, false)
	ns.pendingClick = nil
	return pending.name
end""",
       "an unrelated error blamed on a name",
       script="runscenarios.py")

# 17. a recipient the client would not name, read as "nothing contradicting who
#     it went to". Any cast of the offered buff inside the window then repays
#     that person, whoever actually received it.
mutate("Core.lua",
       "\telseif pending.targeted then\n",
       "\telseif true then\n",
       "a debt settled on a cast nothing connects to it",
       script="runscenarios.py")

# 18. user-typed text handed to gsub as a replacement, where % is an escape.
#     "10% left" in the top-up wording throws on every repaint.
mutate("Core.lua",
       '\treturn ((text or ""):gsub(token, function() return value or "" end))\n',
       '\treturn ((text or ""):gsub(token, value or ""))\n',
       "typed text used as a gsub replacement",
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
       script="runscenarios.py")

# 20. and the other half of it: one empty scan taking the prompt down, so the
#     next scan 0.4s later puts it back with the entrance animation replayed.
mutate("Prompt.lua",
       "			if now - emptyAt < EMPTY_FUSE_SECONDS then return end\n",
       "",
       "an empty scan hiding the prompt at once",
       script="runscenarios.py")

# 20b. and the press disagreeing with the panel while that fuse burns: the
#      prompt is visible and naming somebody, and re-resolving to nobody here
#      disarms it -- so the click does nothing and says nothing, which is the
#      silent failure the fuse was added to avoid, arriving by the other door.
mutate("Prompt.lua",
       "		if not top and FuseStillBurning(now) then return end\n",
       "",
       "a press that disarms a visible prompt",
       script="runscenarios.py")

# 20c. the count of who else is waiting, read off the queue's length instead of
#      counted. The pick is not always queue[1] -- a tie is kept with the
#      current candidate, and a held one is not in the queue at all -- so this
#      is short by one for exactly the people the hold exists for.
mutate("Prompt.lua",
       "	self:Paint(top, others)\n",
       "	self:Paint(top, #queue - 1)\n",
       "a waiting count read off the queue order",
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
       script="runscenarios.py")

# 22. a tick over a cast nobody confirmed. The settle path is careful about the
#     difference between the client naming the person we aimed at and the client
#     refusing to name anybody, and this is the panel throwing that care away --
#     which is worse than the silence it replaced, because it is believed.
mutate("Core.lua",
       '\tShowOutcome(unconfirmed and "sent" or "cast", pending.name)\n',
       '\tShowOutcome("cast", pending.name)\n',
       "a tick over an unconfirmed cast",
       script="runscenarios.py")

# 23. the game's own reason for the failure never reaching the panel. It is
#     localised, it is frequently the only thing that says *why* -- out of
#     range, line of sight -- and it went nowhere unless click debugging was on.
mutate("Core.lua",
       '\t\tShowOutcome("failed", failed, type(message) == "string" and message or nil)\n',
       "",
       "the game's reason kept off the panel",
       script="runscenarios.py")

# 24. the combat hold. The macro is frozen at whoever was on the button when the
#     fight started; without this the panel goes on painting that at full
#     brightness with a live queue listed underneath it.
mutate("Prompt.lua",
       "		self:SetCombatHold(true)\n",
       "",
       "a frozen prompt that still looks live",
       script="runscenarios.py")

# 25. and the tooltip over it, which is the most detailed and most convincing
#     thing the prompt says about a macro that cannot follow anything.
mutate("Prompt.lua",
       '		if InCombatLockdown() then return end\n		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       '		GameTooltip:SetOwner(self, "ANCHOR_TOP")',
       "a tooltip describing a frozen macro",
       script="runscenarios.py")

# 26. the spoken line re-rolled per repaint and again on the press, so the line
#     quoted in the tooltip was never the line that went out. The cache looks
#     like an optimisation and is the only thing making the quote true.
mutate("Prompt.lua",
       "	if phraseKey ~= key then\n",
       "	if true then\n",
       "the tooltip quoting a line it will not cast",
       script="runscenarios.py")

# 27. queue rows lying on the world with no background: unreadable on anything
#     bright, absent on anything dark.
mutate("Prompt.lua",
       "	queueBack:SetShown(back)\n",
       "	queueBack:SetShown(false)\n",
       "a queue list with no background",
       script="runscenarios.py")

# 28. and the same list hanging below a prompt that now sits just above the
#     action bars, which runs it off the bottom of the screen.
mutate("Prompt.lua",
       "	queueAbove = QueueGoesAbove()\n",
       "	queueAbove = false\n",
       "a queue list that runs off the screen",
       script="runscenarios.py")

# 29. an icon larger than the panel it sits in. The slider ran to 64 against a
#     height that runs down to 20.
mutate("Core.lua",
       """	local iconMax = math.max(12, (p.height or ns.defaults.profile.prompt.height) - 8)
	if p.iconSize > iconMax then p.iconSize = iconMax end""",
       "",
       "an icon taller than the prompt",
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
       script="runscenarios.py")

# 31. preview timing out while the options window is open, which is the only
#     time it is any use -- and the reason the prompt could not be styled in a
#     city at all.
mutate("Prompt.lua",
       "		local styling = ns.OptionsOpen and ns.OptionsOpen()\n",
       "		local styling = false\n",
       "preview dying while it is being used",
       script="runscenarios.py")

# 32. two controls sharing an order number. AceConfig breaks the tie on the
#     option's *name*, so the page renders perfectly and puts a slider under a
#     dropdown it has nothing to do with -- which is what "...after this long"
#     did under "If they already have the buff" for four releases.
mutate("Options.lua",
       "order = 23.5,",
       "order = 23,",
       "two controls at the same order",
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
       script="runscenarios.py")

# 34. the unit dropped back out of a slider's name. Four of the five are seconds
#     and the fifth is minutes, and an AceConfig range has nowhere else to put
#     it: "Remember a buff for: 120" and "Top up when under: 5" read as the same
#     kind of number.
mutate("Options.lua",
       "Remember a buff for (seconds)",
       "Remember a buff for",
       "a time slider showing a bare number",
       script="runscenarios.py")

# 35. the sound going off for everybody again while the flash stays choosy. The
#     two are one job and were two tabs apart, which is how they came to
#     disagree about who is worth interrupting for.
mutate("Prompt.lua",
       '		and (not db.sound.owedOnly or top.reason == "owed")\n',
       "",
       "the sound alerting for passers-by",
       script="runscenarios.py")

# 36. the per-spell switches not consulted. The walk offers a class's whole
#     list, and the only way to say "not that one" used to be pinning a single
#     spell -- which switches the walk off altogether.
mutate("Core.lua",
       "		if ns.IsBuffKnown(buff) and not (db and db.buff.skip and db.buff.skip[buff.key]) then",
       "		if ns.IsBuffKnown(buff) then",
       "a spell switched off and offered anyway",
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
       script="runscenarios.py")

# 39. and the quietest of them: a pinned spell you have not learned. The pin is
#     the only spell considered, so nobody is offered anything at all -- and it
#     is deliberately not reset for you, because a failed spell probe must not
#     rewrite a setting.
mutate("Options.lua",
       'hidden = function() return B().choice == "auto" end,',
       "hidden = function() return true end,",
       "no warning for a pin that stops everything",
       script="runscenarios.py")

# 39b. a toggle with nothing behind it. Battle Shout is cast on yourself and
#      heard by your party, so the queue turns down everybody outside the group
#      before the strangers toggle is ever read -- and a control that does
#      nothing reads as a feature that is broken.
mutate("Options.lua",
       "				hidden = OnlyReachesGroup,\n",
       "",
       "a toggle offered to a class it cannot help",
       script="runscenarios.py")

# 40. the target rule ignoring the switch that was added for it. It is a
#     preference about somebody else's queue order, not a fact about them.
mutate("Core.lua",
       '		if unit == "target" and db.priority.target',
       '		if unit == "target"',
       "the target rule with no way off",
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
       script="runscenarios.py")

mutate("Core.lua",
       """	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()""",
       "	local now = GetTime()",
       "debts restored after being switched off",
       script="runscenarios.py")

# 43. the errors the addon already caught, back to being invisible on the one
#     page somebody opens when nothing is working.
mutate("Options.lua",
       "hidden = function() return #ns.errors == 0 end,",
       "hidden = function() return true end,",
       "caught errors kept off the page",
       script="runscenarios.py")

# 44. and the build number out of the block that exists to be pasted into a
#     report -- the first question every report gets, asked of the one screen
#     that could not answer it.
mutate("Options.lua",
       'local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }',
       'local lines = { "Manners" }',
       "a bug report with no build number",
       script="runscenarios.py")

# 45. the combat notice. Every control on the Prompt tab is a secure attribute
#     or a texture on a secure frame, and ApplyStyle returns without doing
#     anything for the length of a fight.
mutate("Options.lua",
       "hidden = function() return not InCombatLockdown() end,",
       "hidden = function() return true end,",
       "a frozen tab that looks like a working one",
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

if dead_anchors or missed or not_restored:
    print()
    for label in dead_anchors:
        print("ANCHOR GONE: " + label)
    for label in missed:
        print("MISSED: " + label)
    for script in not_restored:
        print("NOT RESTORED: " + script + " is red on a tree that started green")
    # The four suites are the project's only gate. One of them reporting a
    # check that is switched off as success is how the stale-macro guarantee
    # stayed dead through three releases.
    print("RESULT: the suite is not proving what it claims")
    sys.exit(1)

print()
print("RESULT: every mutation was caught")
