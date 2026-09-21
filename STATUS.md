# Where this stands

Working notes, current as of v0.9.5. Not part of the shipped addon — `.pkgmeta`
leaves it out.

## Done

The addon works end to end: it finds nearby players missing your buff, notices
who buffed you without a combat log, and casts. Published to GitHub and
CurseForge, with releases automated on a git tag.

Publishing is fully wired — `CF_API_KEY` is a repo secret, the project id is in
the toc, and `git tag vX.Y.Z && git push origin vX.Y.Z` runs the suites,
packages with libraries fetched as externals, makes a GitHub release and
uploads to CurseForge.

## Open

**Only Mage has cast in game.** Priest, Druid, Paladin, Warlock and Warrior are
implemented and their cast paths are exercised by `tests/runscenarios.py`, but
nobody has used them. Warrior is the one to test first: Battle Shout is
`selfCast` and builds a structurally different macro with no `/target` line.

**Real player names are in git history.** They were scrubbed from the working
tree in v0.9.5 but remain in earlier commits — roughly eleven occurrences. The
repo has no forks, so a history rewrite is cheap if wanted.

**An improvement audit produced 103 findings.** Eight bugs are fixed in v0.9.5.
The remainder — UX, options page structure, code quality and performance — are
not yet worked through, and a feature recommendation was still being
synthesised.

## Rules worth not relearning

- `python tests/setversion.py X.Y.Z` sets the version. Never edit the three
  files by hand; doing so produced a mismatch twice.
- Run all four test scripts after any change. `tests/selftest.py` is the one
  that proves the others can still fail — a suite that cannot go red is worse
  than none.
- `Libs/` is deliberately absent from the repository. A zip built from a clone
  will not load. Build through the workflow.
- When the API misbehaves, grep the other addons under
  `D:\wow\World of Warcraft\_classic_beta_\Interface\AddOns`. They are code
  known to work on this exact client, and they settled several questions that
  documentation got wrong.
