# Cleanup plan

Working notes, not shipped (`.pkgmeta` leaves it out). Written 2026-09-25,
after 1.0.0-beta.6, when Sacha asked whether the code was bloated. It is the
plan to follow when Sacha asks for "the cleanup". Nothing in it has been done
yet; tick steps off here as they land.

**Goal:** a smaller addon that is quicker to test, with no change in behaviour.
A trim, not a rewrite.

## Where it stood (beta.6, commit 2e5c01f)

| | |
|---|---|
| Shipped Lua | 16,876 lines: 6,679 comment (40%), 1,103 blank, ~9,100 code |
| Biggest files | Core.lua ~7,400, Prompt.lua ~3,600, Options.lua ~3,500, Ledger.lua ~1,600 |
| Tests (not shipped) | 30,444 lines; 545 mutations |
| Player-facing strings | 774, 47,337 characters; 30 over 200 characters (23 in Options.lua, 4 in Ledger.lua, 3 in Core.lua) = 7,690 characters |
| Translations | nine Locales/*.lua files, 1.1 MB together |
| Full selftest | ~25 min on a 16-core desktop; **2 h 21 min on GitHub's runner** |

The release workflow re-runs the whole selftest after CI already ran it on the
same commit, so a release took over two hours for no new information.

## Steps, in order

### 0. Make testing fast first

Everything after this step is paid for by it, and so is every future release.

- [x] (done in 1.0.0-beta.7: the release runs `selftest.py --anchors`)
      `.github/workflows/release.yml`: stop re-running the full
      `tests/selftest.py`. CI on master has gated the commit already; the
      release keeps validate, runharness, runscenarios and
      `selftest.py --anchors`. Keep `tests/validate.py`'s "release gates"
      check honest about what it now requires (it reads both workflows).
- [x] `tests/selftest.py`: judge each mutation by the scenarios it names, not
      the whole suite -- a `runscenarios.py` filter (by scenario name or by
      `tests/scenarios/<file>.lua`) that `mutate()` passes through, falling
      back to the full suite only where `expect` cannot be mapped.
      (Done: `--scenario`/`--file`/`--select`; the mapping comes from a line
      trace of the scenario files, `runscenarios.py --trace`. All 615
      runscenarios.py mutations map (the other 20 of 635 are judged by
      validate.py or runharness.py, fast already); 12 in asked.lua fall back
      to their whole file because their scenarios lean on a helper load. A
      narrowed miss is re-judged on the whole suite, and a narrowed selection
      must be green on the clean tree first. `selftest.py --plan` shows it.)
- [x] Run mutations in parallel (each on its own copy of the tree -- they edit
      files in place, so never two in one directory).
- [x] `tests/scenarios/locales.lua` drives the addon in ten client locales on
      every run; run it once per selftest, not once per mutation, unless the
      mutation touches `Locales/`.
- [x] (added) `tests/validate.py` reads each function's upvalue count and most
      active locals out of Lua 5.1 bytecode (`tools/lua51_limits.py`) and fails
      over 55 upvalues or 190 locals -- the early warning beta.6 lacked.
- Target: full selftest under 10 minutes locally, under 20 on GitHub. Prove
  the gate still works: every mutation still CAUGHT by its named check.
  Measured 2026-09-27 on the 16-core desktop, while six other agents ran their
  own suites on it: 110 s with 16 workers, 101 s with `--jobs 4` (a GitHub
  runner's four cores), 292 s at the busiest; every run "RESULT: every
  mutation was caught" (635 mutations). CI runs it in full on every push.

### 1. Shorten the long texts

- [ ] The 30 strings over 200 characters: cut each to one or two sentences a
      player acts on; move the detail to README.md. List them with:
      `python -c "import sys; sys.path.insert(0,'tools'); import locale_keys as lk; k,_=lk.keys(); [print(len(x), v[0], x[:80]) for x,v in sorted(k.items(), key=lambda i: -len(i[0])) if len(x)>200]"`
- [ ] Also look at option descriptions between 120 and 200 characters.
- [ ] Changed keys drop out of every locale file (tools/build_locale.py drops
      keys no longer asked for). Top them up: `tools/locale_keys.py --missing
      <code>` per language, translate with the glossaries (kept in the session
      scratchpad of the translation run -- if gone, write a short one per
      language from the existing Locales/<code>.lua terms), rebuild with
      tools/build_locale.py, check with tools/check_translation.py.
- Scenarios assert on English text in many places: update those that quote a
  shortened string, never weaken what they check.

### 2. Developer tools out of the player's way

- [ ] `/manners try`, `look`, `forms`, `clicks` (and the click log) leave the
      help list and move under one `/manners dev` (which lists them). Keep
      them working: they are the only in-game diagnosis for the classes nobody
      has played. Update ns.COMMANDS, the did-you-mean list, README and the
      ease scenarios that walk the command list.

### 3. Trim the comments

- [ ] Cut history narration ("this used to do X, which broke Y ...") down to
      the rule that holds now and why. Keep every comment that explains a
      client quirk, a secret-value rule, a combat restriction or a deliberate
      decision (STATUS.md "Worth knowing about").
- Target ~25% comment lines, from 40%. Comments only: `python tests/baseline.py`
  output must be byte-identical before and after; mutation anchors that sit on
  comment text must be re-anchored, not deleted (`selftest.py --anchors`).

### 4. Dead and duplicate code

- [ ] Remove only what a tool proves unused: extend validate.py's
      "WRITE-ONLY ns.X" check to local functions nothing calls, and delete what
      it finds.
- [ ] Look for the same fix made twice from different files by parallel
      fixers (found twice already: the never-offer list's ledger row and its
      in-fight warning). Symptoms: a chat line said twice, a mutation that
      goes MISSED after a merge.
- Keep the fallbacks that guard untested classes and clients.

### 5. Measure CPU in a crowd

- [ ] Profile a scan with 40 nameplates, a full raid, many auras, a long
      never-offer list and a friends list of 100 (a lupa probe on the mock).
      Report time per BuildQueue/Tick and table allocations per tick; fix only
      what is actually expensive, with English behaviour identical.

## Out of scope

Rewriting modules; removing safety fallbacks; new features; behaviour
changes. The half-finished round 4 branches (`r4/look2`, `r4/ledgerui`,
`r4/asked`, `r4/perf`, worktrees under the session scratchpad) were stopped
before review and are not part of this -- delete them, except that
`r4/perf` may hold a profiling probe worth reusing for step 5.

## How to run it

- Worktrees for any agent that edits code; never the live tree.
- Few agents, not big fan-outs: step 0 by one agent; steps 1-4 one agent per
  file in parallel; step 5 one agent. Fast suites while working, one full
  selftest at the end (fast by then).
- Guardrails: English output identical except the shortened texts; all
  suites green; every mutation CAUGHT; then one release via RELEASING.md.
- Expected cost: 2-3 hours of wall time.
