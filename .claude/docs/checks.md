# Manners -- checks, CI and dev tools

Every check and its flags, how many jobs, what CI runs, and the helpers for
working in a worktree. Moved out of `CLAUDE.md`, word for word; `CLAUDE.md` is
the index, read first.

## Checks

| Command | What | Time |
|---|---|---|
| `python tools/lint.py` | every Lua file (Lua 5.1) and Python file compiles, the generated tocs are current; `file:line: what` per problem | under 1 s |
| `python tools/check.py` | validate, runharness, runscenarios (Forever); one summary line per step, non-zero on any failure | minutes |
| `python tools/check.py --lint` | lint first, and nothing else runs if it fails | |
| `python tools/check.py --flavours` | also each client's own scenario file as that client (era.lua as vanilla, tbc.lua, mists.lua, mainline.lua), every `tests/scenarios/*-fixes.lua` as each client, and `unverified.lua`, `hunt23-queue.lua` and `hunt23-favours.lua` as mainline (retail hides auras in a fight as Forever does) | longer |
| `python tools/check.py --anchors` | also `tests/selftest.py --anchors` | seconds more |
| `python tools/check.py --baselines` | also the WHOLE suite as each of vanilla, tbc, mists and mainline, in 8 pieces a client (`runscenarios.py --flavour X --baseline --part I/8 --jobs 1`), red on any failure not written down in that piece's section of `tests/baselines/<X>.txt` | about 95 min of two cores, some 32 min at `--jobs 6` |
| `python tools/check.py --release` | **everything before a release, one command**: `--baselines` too; lint, then validate, harness, anchors, `tools/locale_keys.py`, `tools/make_look_previews.py --check` and `tests/bughunt.py` (counted, never red) side by side, the scenarios on Forever, `tools/fuzz.py --quick` on five clients, then each other client's files with `tools/audit_look_contrast.py --check`; one line per step, each red step followed by the command that shows it alone, and the wall time | 10 min 39 s at `--jobs 6` (105 steps) |
| `python tools/prove.py "<label text>"` or `--file tests/mutations/<topic>.py` | **the proof of a new mutation while building**: its topic's scenario file and every scenario file holding its `expect`, green on the clean tree, then with the mutation in a throwaway copy. CAUGHT, MISSED, WRONG CHECK, ANCHOR GONE, RED BEFORE, NO FILE. No trace, no whole suite | 2 to 25 s a scenario file; `thank.py`'s 56 mutations in 41 s at `--jobs 6` |
| `python tests/selftest.py --changed [REF]` | the mutations of every file that differs from REF, committed or not (default master): code, tests, docs and workflows alike. With no trace kept of these tests it tries each on its own scenario files first (prove.py's rule) and traces only for the ones that leaves; `judged by:` under each says which rule | seconds to a few minutes when the fast proof catches them all; the trace (tens of minutes) only for what is left |
| `python tests/selftest.py --only "<label>"` | the same for the mutations whose label or file holds the text | as above: 3 mutations in 17 s where it used to trace the suite first |
| `python tests/selftest.py` | every mutation (about 6,000), each judged by the check it names; `--part I/N` one share of them | hours locally; on GitHub `selftest.yml` runs it in 16 parts |

`--jobs N` on check.py, prove.py, fuzz.py, runscenarios.py and selftest.py
defaults to `tools/jobs.py`'s number: the cores less two, fewer when free
memory is short (0.75 GB a job), and never more than `MANNERS_JOBS` when that
is set (`python tools/jobs.py` prints it and why). Set `MANNERS_JOBS=6` once
while other agents share the machine rather than `--jobs` on every command.
While building, prove each new mutation with `tools/prove.py`; before handing
work back, `check.py --lint --flavours --anchors` and `selftest.py --changed`;
the full selftest runs on GitHub (`selftest.yml`) and the release tool reads
it. Before a release, `check.py --release` and `RELEASE-CHECK.md` (five
minutes in the game, by the author).

`tests/runscenarios.py` flags: `--scenario NAME` and `--file FILE`
(`scenarios.lua` or a file in `tests/scenarios/`; both repeatable),
`--select pick.json`, `--jobs N`, `--flavour X` (the whole suite with X as
`Mock.reset()`'s client; same as `MANNERS_MOCK_FLAVOUR=X`), `--flavour X
--baseline` (prints only failures not in `tests/baselines/<X>.txt`, and
baseline entries that now pass; `--update-baseline` rewrites the file;
`--part I/K` with either does one K-th of the pieces, so a client's suite
can be compared or written down in runs of a few minutes: the file holds a
section per piece, `## scenarios.lua 3/8` or `## <topic file>`, and a red is
known only in its own piece's section), `--trace PATH` and `--shard I/K`
(used by selftest). A run ends with `failures: N`. Off Forever most reds are
fixtures written for Forever (two-part names, scrolls, secrets), which is what
the baselines hold. `scenarios.lua` runs to its end on every client: a block
about a buff another client lacks (Wisdom, Divine Spirit on Mists and retail)
asks `hasBuffs` and is a skip there, where it used to throw and stop the file
at line 738 with 299 scenario loads after it. Write a baseline only from a
run you have read: a line it adds is a red accepted.

`tests/selftest.py` flags: `--anchors` (every mutation still finds its text),
`--changed [REF]`, `--only TEXT`, `--plan` (which scenarios judge each
mutation), `--whole` (every mutation on the whole suite, slow), `--fresh-trace`
(ignore the trace kept in `%TEMP%/manners-selftest-trace`, and trace even
where the fast proof would do), `--jobs N`. A run fails on MISSED, WRONG
CHECK, ANCHOR GONE or NOT RESTORED. A narrowed run that keeps no mutation
ends at once.

Others: `tests/baseline.py` (a fingerprint of what Forever decides and arms:
diff it before and after a change made for another client), `tests/bughunt.py`
(known fault shapes; reports known false positives), `tools/lua51_limits.py`
(the tightest functions), `tools/perf_probe.py` and `tools/profile_scan.py`
(pcall counts, cost per scan), `tools/render_prompt.py`, `render_ledger.py`,
`render_options.py` (draw the UI from the mock; not pixel-true about light),
`tools/audit_look_contrast.py` (every look's words measured on the pictures:
4.5:1 for each line, `--check`; run it after any change to a look).

CI (`ci.yml`, every push): validate, runharness, `selftest.py --anchors`,
runscenarios (`--jobs 4`), and the listing images drawn with `--strict`.
`release.yml` runs only validate, runharness and `--anchors` before packaging:
`tools/release.py` tags only content CI passed. The full
selftest is `selftest.yml`: sixteen runners, one `--part I/16` each, nightly, on
every push to master and on `gh workflow run selftest.yml`; `gh workflow run
selftest.yml --ref <branch>` proves a branch before it is merged, and the
release tool counts that run once the branch is in master. Each part runs
`--jobs 3` with every process held to 4 GB of address space, its step under
335 minutes in a job of 350; a run of master is never cancelled by a newer
push (that one waits, only the newest waiting runs next), and the trace is
saved whatever the part's verdict. A mutation the
pieces of the suite judged is remembered by the piece that caught it
(`catches.json` beside the kept trace) and tried there first next time.

Nothing here talks to a running client. For the game itself, ask the user to
run `/manners selftest launch` (a report to paste) or the `/manners dev` tools
(`clicks`, `try`, `look`, `forms`) and paste the output, or for a screenshot.

## Dev tools

Quick helpers for working in a worktree (`tools/README.md` has the details):

- `python tools/lint.py [FILE ...]`: Lua 5.1 syntax of every file the toc loads
  plus `tests/*.lua`, `tests/scenarios/*.lua` and `tools/*.lua`, every `.py`
  under `tools/` and `tests/` compiled, and the generated tocs current. One
  `file:line: what` per problem, exit 1. Under a second. It does not count
  upvalues or locals: `tests/validate.py` does. `--quick` is the hook's form.
- `python tools/anchors_for.py FILE[:LINE[-LINE]|:FUNCTION]` **before** editing
  a line: the mutations whose `old` text sits there (within 3 lines, `--near N`),
  each with its label, its `expect` and the file:line of its `mutate()` call.
  `python tools/anchors_for.py --check-after` **after**: only the mutations that
  no longer find their text (`selftest.py --anchors`, gone ones only; exit 1
  too when a mutation file does not run). Re-aim them in the same change,
  never delete them.
- `python tools/clients_watch.py`: each client's interface number and build in
  the repo against `Gethe/wow-ui-source` (`version.txt` per branch) and
  `Ketho/BlizzardInterfaceResources`, plus the PTR and beta branches. Exit 1 on
  drift (a toc that would show out of date to players on that client) or when
  the repo's own sources disagree; 2 when upstream cannot be read. Needs `gh`.
- `python tools/prove.py "<label text>" [...]` or `--file
  tests/mutations/<topic>.py` (`--list` says what would run): a new mutation
  proven in seconds, on its topic's scenario file and the files that hold its
  `expect`. This is what to run after writing a scenario and its mutation,
  not `selftest.py --only`. MISSED there means "not in those files": a check
  that lives elsewhere (a control's place in `layout.lua`) needs its scenario
  named in `expect`, or `selftest.py --only` to find it.
- `python tools/check.py --lint --flavours --anchors`: lint first, then the
  rest; a lint failure stops it before anything else runs. `--release` is the
  same and the locales, the looks' previews and contrast, bughunt and the
  quick fuzzer: the one command before a release.
- `python tools/jobs.py`: how many processes the tools run at once by default
  and why; `MANNERS_JOBS=N` caps them all.
- `.claude/settings.json` allows the commands above, `python tools/*`,
  `python tests/*`, the everyday git (`git branch` only to list) and `gh run`
  commands and `gh api` reads of the two upstream repos (every flag that makes it
  a write is denied); it asks before `tools/release.py` and `tests/setversion.py`,
  and denies force pushes, `git reset --hard`, `git clean`, forced or `-D`
  branch changes, `rm -rf` and `gh secret`. A PostToolUse hook runs
  `tools/lint.py --quick` (from `$CLAUDE_PROJECT_DIR`, so a `cd` does not break
  it) after every Edit or Write: it is silent when the file compiles and prints
  the problem (exit 2) when it does not. Slash commands in `.claude/commands/`:
  `/check`, `/release`, `/bughunt`, `/translate`, `/phrases`.
- `python tools/perf_probe.py [--flavour X] [--compare before.json]`: pcalls,
  client calls and allocations per scan in idle, city, dungeon, raid, raidgc
  and citynever, as any of the five clients. Measure before and after a change
  to a hot path; `python tests/baseline.py` (what Forever decides and arms) must
  stay identical across a performance change. `tools/profile_scan.py` is
  Forever-only (its fixtures use two-part names).
- Audits (each documents itself with `-h`; none is part of `check.py`; they
  download client data into a cache outside the repo): `tools/audit_ids.py
  [--client X] [--notes]` holds every spell, item, aura, race and class id the
  addon has to that build's wago.tools tables (run it after any change to
  `Buffs.lua`); `tools/audit_groups.py` the group casts; `tools/audit_api.py`
  every client API, event, CVar and widget method the addon uses against each
  client's own API, saying which uses are guarded and which would throw (run it
  before adding an API call, or when a toc moves to a new build; `audit_apis.py`
  is the lighter version with `--textures`, `--globals` and `--ptr`, and
  `audit_docs.py` reads Blizzard's own API documentation for what is secret or
  restricted); `tools/migration_check.py` loads every release tag's addon on the
  mock, saves its settings and loads them in the current addon (a setting a past
  release saved that the current one mangles is a finding);
  `tools/audit_saved_boxes.py` and `tools/legacy_lines.py` the In character
  phrase box across releases and languages; `tools/audit_i18n_*.py` lead lists
  for translators (formats, widths, gender, terms, references).
- `python tools/fuzz.py --quick --jobs 2`: a seeded random game (rosters, auras,
  deaths, fights, chat, presses, withheld values, settings, reloads) played on
  every client with invariants checked after each step: 24 seeds x 5 clients x
  100 steps, about 30 s. `--seeds N [--flavour X] [--steps M]` for more (500
  seeds on every client is about 13 minutes with `--jobs 2`); a failure prints
  `flavour=X seed=S`, replay it with `--flavour X --seed S [--trace]`, shrink it
  with `--minimize`, which prints a quoted `--play '<steps>'` line. 10,000 runs
  of 200 steps found no addon fault at 1.7.4 beyond one the reviewer caught; run
  it after any change to the queue, the aura or event handlers, or the macro.
- Edit nothing under `tests/` or the addon while `check.py` or `selftest.py`
  runs: each scenario process keeps a compiled copy of every file, and a change
  mid-run fails the step with "changed during the run" while still printing
  `failures: 0`. The selftest trace is keyed on the tests (and on `--jobs`);
  after a test edit `--changed` and `--only` no longer trace first: they try
  each mutation on its own scenario files and trace only for what that leaves.
