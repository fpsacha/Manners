"""Prove the harness still detects the fault classes that actually happened,
by reintroducing each one, running, and putting the file back.

A suite that cannot go red proves nothing, so this is run whenever the addon
is restructured -- a refactor can quietly move the code a check depends on.
"""
import subprocess, shutil, sys, os

DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(DIR, "tests")


def run(script):
    r = subprocess.run([sys.executable, os.path.join(TESTS, script)],
                       capture_output=True, text=True)
    return r.stdout


def mutate(filename, old, new, label, script="runharness.py"):
    path = os.path.join(DIR, filename)
    backup = path + ".selftest-backup"
    shutil.copy2(path, backup)
    try:
        s = open(path, encoding="utf-8").read()
        if old not in s:
            print("%-44s *** ANCHOR GONE -- check is no longer live ***" % label)
            return
        open(path, "w", encoding="utf-8", newline="\n").write(s.replace(old, new, 1))
        out = run(script)
        caught = ("errors: 0" not in out) and ("failures: 0" not in out)
        print("%-44s %s" % (label, "CAUGHT" if caught else "*** MISSED ***"))
        if caught:
            for line in out.split("\n"):
                if line.strip().startswith("  ") and line.strip():
                    print("      " + line.strip()[:96])
                    break
    finally:
        shutil.move(backup, path)


print("baseline:")
for script in ("runharness.py", "runscenarios.py"):
    line = [l for l in run(script).split("\n") if l.startswith(("errors:", "failures:"))]
    print("  %-20s %s" % (script, line[0] if line else "?"))
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
			"type", "macrotext", "spell", "unit" }) do
			button:SetAttribute(attribute, nil)
		end
		appliedKey = nil""",
       """		if appliedKey ~= nil then
			for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
				"type", "macrotext", "spell", "unit" }) do
				button:SetAttribute(attribute, nil)
			end
			appliedKey = nil
		end""",
       "stale macro on an emptied queue",
       script="runscenarios.py")

print()
print("after restore:")
for script in ("runharness.py", "runscenarios.py"):
    line = [l for l in run(script).split("\n") if l.startswith(("errors:", "failures:"))]
    print("  %-20s %s" % (script, line[0] if line else "?"))
