# Instructions for AI coding agents

This project's full guide is written for agents in general, whatever the tool.
Before doing anything, read these files, in this order:

1. `CLAUDE.md`: the project guide and its hard rules (the name is historical;
   it applies to every agent).
2. `.claude/docs/lessons.md`: what the last sessions learned (the 1.11.41
   rollback, what WoW Forever hides from addons, releasing, answering players).
3. `STATUS.md`: where things stand.
4. `.claude/docs/plan-modules.md`: the hand-off with the current work (issue
   44 first, then the optional modules).

The topic files under `.claude/docs/` hold the detail for each area; `CLAUDE.md`
lists them.

Most important rules: Manners stays small (nothing new ON by default); work in
a git worktree, not on `master` directly; tests run with
`python tests/runscenarios.py --file <file>.lua --jobs 2` and
`python tools/check.py --lint --anchors --quick`; releases go through
`python tools/release.py X.Y.Z`; never name another addon anywhere.
