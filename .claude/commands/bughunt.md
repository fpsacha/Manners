---
description: Run a bug hunt as a workflow: finders per area, skeptics that try to refute, fixers in worktrees
argument-hint: "[areas, e.g. logic ui clients]"
---
The shape used for 1.7.3 and the rounds since: **find, then refute, then fix**,
one git worktree and branch per area, merged afterwards by you. Areas: `$ARGUMENTS`
(default: split the toc's files so no two areas share a file; Core.lua, Queue.lua
and Favours.lua are shared by everything, so keep changes there to single lines).
Write it as one Workflow script (`workflow-authoring` has the API).

**Setup (you, before the script).** `N` = the round number (`git branch` shows the
last `rN/...`). Per area: `git worktree add <scratchpad>/wtN-<area> -b rN/<area> master`.
Cores: `--jobs 2` for every agent, five areas at once (cores less two, shared).

**1. Find** (read-only; 2 to 4 finders per area, each with its own lens: a flow
end to end, one client's data against its wago.tools DB2 or Blizzard's UI source,
secret values and names, combat lockdown and the 255-character macro, the options
window). `python tests/bughunt.py` is a cheap first pass. A finding is
`{file, line, claim, input_state -> wrong_output, clients, severity}`; one without
a concrete input and wrong output is dropped. Dedupe across finders by file and line.

**2. Refute** (per finding, three skeptics with different lenses, all told "try to
refute it; refuted unless you can show it": read the code, check the client data,
and write the scenario). A finding stands if at most one refutes and a scenario
`<area>-fix: ...` is red on the unfixed tree (or the cited DB2 row or Blizzard
source line shows it). What only the game can settle is not fixed: list it for
STATUS.md "Open". Keep the refuted ones, with the reason, and hand them to the
next round's finders so they are not found again.

**3. Fix** (one fixer per area, in that area's worktree). Prompt it with the same
text each time: read CLAUDE.md, STATUS.md; work only in `<worktree>`; the area's
files only, shared files minimal and local; `--jobs 2` on check.py, runscenarios.py
and selftest.py; no new or changed `L["..."]` (list it under needs_strings
instead); no behaviour change except a proven fix; Lua 5.1 limits; no pcall on
busy paths. Per fix: a scenario in `tests/scenarios/<area>-fixes.lua`, a mutation
in `tests/mutations/<area>-fixes.py` undoing it, proven with
`python tests/selftest.py --only "<label>" --jobs 2`; before editing a line,
`python tools/anchors_for.py FILE:LINE`; after,
`python tools/anchors_for.py --check-after` and re-aim what moved. Finish with
`python tools/check.py --lint --flavours --anchors --jobs 2`, then
`python tests/selftest.py --changed master --jobs 2`, then `git add` and commit
ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. No push.
Its schema: `{commit, done[], skipped[], numbers, needs_strings[], docs_notes[], tests}`.

**4. Merge (you).** Merge each `rN/<area>` into `rN/merge`; look for the same fix
made twice (a line said twice, a mutation gone MISSED). Then
`python tools/check.py --lint --flavours --anchors`, `python tests/selftest.py
--changed master`, and `--flavours` baselines if a fix moved a known red
(`runscenarios.py --flavour X --baseline`). Strings in needs_strings: `/translate`.
docs_notes: into CLAUDE.md, tools/README.md, STATUS.md. Notes for players under
`## Unreleased` in CHANGELOG.md, with no disclaimers. Run the full selftest once
before a release (`/release`). Remove the worktrees when merged.

Skeleton: `pipeline(areas, findStage, refuteStage)` (no barrier between areas), then
one `parallel` over areas for the fixers, each `agent(prompt, {schema: REPORT})`.
Log what was dropped at each stage; no silent caps.
