# Manners -- scenarios and mutations

How a scenario and its mutation are written, named, anchored and proven. Moved
out of `CLAUDE.md`, word for word; `CLAUDE.md` is the index, read first.

## Scenarios and mutations

- **Scenarios** are Lua run against the mock. `tests/scenarios.lua` is the old
  main file (do not append to it); new ones go in `tests/scenarios/<topic>.lua`,
  found by glob and run after the main file in name order. A file starts
  `local dir, H = ...` and takes helpers from `H` (`fail`, `load`, `drive`,
  `strangers`, `freshPrompt`, `pressButton`, `owe`, ...: the table near the end
  of `scenarios.lua`). Shape: `Mock.reset()`, set the mock
  (`Mock.setFlavour("mists")`, `Mock.class = "PRIEST"`, ...),
  `local ns = load(scenario)`; `nil` means "skip" (a narrowed run left it out);
  report with `fail(scenario, text)`. Put back every global you replace.
- **Names** start with the file's topic (`"flows-fix: vanilla: ..."`,
  `"era: ..."`) so a mutation can name exactly one.
- **Mutations** live in `tests/mutations/<topic>.py`, found by glob and run with
  `mutate()` in scope:
  `mutate(file, old, new, label, expect=..., script="runscenarios.py")`.
  `old` is exact code text (first occurrence is replaced; make it unique),
  `expect` is matched case-insensitively against the failing lines (usually a
  scenario name), `script` is the suite that must catch it (default
  `runharness.py`; `validate.py` for doc and structure checks). Every fix gets
  a scenario and a mutation that undoes the fix.
- **Anchors**: changing code or comments a mutation's `old` sits on means
  updating that mutation so it still applies the same fault;
  `python tests/selftest.py --anchors` must report every anchor live.
  `python tools/anchors_for.py FILE:LINE` lists them before the edit and
  `--check-after` only the gone ones after it ("Dev tools" in `.claude/docs/checks.md`).
- **Anchors outside the code**: mutations also sit on `README.md`,
  `RELEASING.md`, `CHANGELOG.md`, `Manners.toc` and both workflows
  (`ci.yml`, `release.yml`), mostly judged by validate.py. One README anchor,
  in the player text about the wrong Mort, is judged by runscenarios.py: a
  scenario in `scenarios.lua` reads `README.md` and fails when the README
  promises more than the code does. Rewording any of these files means
  running `--anchors` too.
- A scenario that cannot go red is worse than none: run the mutation and see it
  CAUGHT by the named check. `python tools/prove.py "<label text>"` does that
  in seconds (`--file tests/mutations/<topic>.py` for a whole file, `--jobs N`):
  the topic's scenario file and every scenario file holding the `expect`,
  green on the clean tree first, then with the mutation in a throwaway copy.
  CAUGHT is the proof; MISSED means "not in those files" (name the scenario
  in `expect`), WRONG CHECK that another check failed and the named one did
  not, RED BEFORE that the scenario file is red without the mutation. A
  mutation re-aimed after an edit is proven again the same way.
- **Timers.** A scenario that reads `Mock.timers` shares the clock with
  everything the login parks on it (the reminder to set a key, twenty seconds
  in; the line said once in town, twelve): take those off first
  (`ns.KeyNudge = nil`, as `hunt24-favours.lua` does) or look for your own
  timer by what it does, not by its place in the list.
- **Nothing on `ns` for the tests alone.** `tests/validate.py` fails a symbol
  put on `ns` that only `tests/scenarios/*.lua` read ("WRITE-ONLY"): a
  scenario sees a module's memory by what the addon then does (the queue, the
  macro, a line of `/manners debug`), not through a table exposed for it.
